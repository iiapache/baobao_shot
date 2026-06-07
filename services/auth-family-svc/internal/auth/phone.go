package auth

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

const (
	regionCN = "cn"

	codeDigits           = 6
	codeTTL              = 5 * time.Minute
	resendCooldown       = 60 * time.Second
	sendCodeWindow       = 60 * time.Second
	sendCodeMaxPerWindow = 3
	sendCodeHourWindow   = time.Hour
	sendCodeMaxPerHour   = 10
	loginWindow          = 60 * time.Second
	loginMaxPerWindow    = 5
)

var (
	cnPhonePattern = regexp.MustCompile(`^1[3-9]\d{9}$`)

	// ErrRateLimited indicates the client exceeded configured rate limits.
	ErrRateLimited = errors.New("rate limited")
	// ErrInvalidPhone indicates the phone number format is invalid.
	ErrInvalidPhone = errors.New("invalid phone")
	// ErrInvalidCode indicates the verification code is wrong or expired.
	ErrInvalidCode = errors.New("invalid verification code")
)

// SMSSender delivers verification codes (mock logs in dev).
type SMSSender interface {
	Send(ctx context.Context, phone, code string) error
}

// MockSMSSender logs codes instead of calling Aliyun SMS.
type MockSMSSender struct{}

// Send logs the verification code for dev/test.
func (MockSMSSender) Send(_ context.Context, phone, code string) error {
	slog.Info("mock sms sent", "phone", maskPhone(phone), "code", code)
	return nil
}

// PhoneAuthService handles SMS code send and phone login flows.
type PhoneAuthService struct {
	users        store.UserStore
	verification store.VerificationStore
	sendLimiter  *SlidingWindowLimiter
	loginLimiter *SlidingWindowLimiter
	sms          SMSSender
	tokens       *TokenService
	now          func() time.Time
}

// NewPhoneAuthService wires dependencies with sensible defaults.
func NewPhoneAuthService(users store.UserStore, verification store.VerificationStore, sms SMSSender, tokens *TokenService) *PhoneAuthService {
	if sms == nil {
		sms = MockSMSSender{}
	}
	return &PhoneAuthService{
		users:        users,
		verification: verification,
		sendLimiter:  NewSlidingWindowLimiter(),
		loginLimiter: NewSlidingWindowLimiter(),
		sms:          sms,
		tokens:       tokens,
		now:          time.Now,
	}
}

// SendCode generates a 6-digit code, enforces rate limits, and mock-sends SMS.
func (s *PhoneAuthService) SendCode(ctx context.Context, phone, clientIP string) error {
	if !ValidateCNPhone(phone) {
		return ErrInvalidPhone
	}

	now := s.now().UTC()
	region := regionCN

	if last, ok, err := s.verification.LastSentAt(ctx, phone, region); err != nil {
		return err
	} else if ok && now.Sub(last) < resendCooldown {
		return ErrRateLimited
	}

	sendKey := fmt.Sprintf("send:%s:%s", phone, clientIP)
	if !s.sendLimiter.Allow(sendKey, now, RateLimitConfig{Window: sendCodeWindow, Max: sendCodeMaxPerWindow}) {
		return ErrRateLimited
	}
	if !s.sendLimiter.Allow(sendKey+":hour", now, RateLimitConfig{Window: sendCodeHourWindow, Max: sendCodeMaxPerHour}) {
		return ErrRateLimited
	}

	code, err := resolveVerificationCode(codeDigits)
	if err != nil {
		return fmt.Errorf("generate code: %w", err)
	}

	expiresAt := now.Add(codeTTL)
	if err := s.verification.SaveCode(ctx, phone, region, code, now, expiresAt); err != nil {
		return err
	}
	return s.sms.Send(ctx, phone, code)
}

// LoginResult is the outcome of a successful phone login.
type LoginResult struct {
	User      *model.User
	IsNewUser bool
	Tokens    TokenPair
}

// Login verifies the SMS code, applies login rate limits, and registers or loads the user.
func (s *PhoneAuthService) Login(ctx context.Context, phone, code, clientIP, deviceID string) (*LoginResult, error) {
	if !ValidateCNPhone(phone) {
		return nil, ErrInvalidPhone
	}
	if len(code) != codeDigits {
		return nil, ErrInvalidCode
	}

	now := s.now().UTC()
	loginKey := fmt.Sprintf("login:%s:%s", phone, clientIP)
	if !s.loginLimiter.Allow(loginKey, now, RateLimitConfig{Window: loginWindow, Max: loginMaxPerWindow}) {
		return nil, ErrRateLimited
	}

	region := regionCN
	if err := s.verification.VerifyAndConsume(ctx, phone, region, code, now); err != nil {
		switch {
		case errors.Is(err, store.ErrVerificationMismatch),
			errors.Is(err, store.ErrVerificationExpired),
			errors.Is(err, store.ErrVerificationNotFound):
			return nil, ErrInvalidCode
		default:
			return nil, err
		}
	}

	user, err := s.users.FindByPhone(ctx, phone, region)
	isNew := false
	if errors.Is(err, store.ErrNotFound) {
		isNew = true
		user, err = s.users.CreatePhoneUser(ctx, store.CreatePhoneUserInput{
			ID:       newUserID(),
			Phone:    phone,
			Region:   region,
			Nickname: defaultPhoneNickname(phone),
		})
		if err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	} else {
		user, err = s.users.TouchLastSeen(ctx, user.ID)
		if err != nil {
			return nil, err
		}
	}

	if deviceID == "" {
		deviceID = "legacy-phone"
	}

	tokenPair, err := s.tokens.IssueForUser(ctx, user.ID, user.Region, deviceID)
	if err != nil {
		return nil, err
	}

	return &LoginResult{
		User:      user,
		IsNewUser: isNew,
		Tokens:    tokenPair,
	}, nil
}

// ValidateCNPhone checks mainland China mobile format.
func ValidateCNPhone(phone string) bool {
	return cnPhonePattern.MatchString(phone)
}

func resolveVerificationCode(length int) (string, error) {
	if fixed := strings.TrimSpace(os.Getenv("MOCK_SMS_FIXED_CODE")); len(fixed) == length {
		return fixed, nil
	}
	return generateNumericCode(length)
}

func generateNumericCode(length int) (string, error) {
	max := big.NewInt(1)
	for i := 0; i < length; i++ {
		max.Mul(max, big.NewInt(10))
	}
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%0*d", length, n.Int64()), nil
}

func defaultPhoneNickname(phone string) string {
	if len(phone) < 7 {
		return phone
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}

func maskPhone(phone string) string {
	if len(phone) < 7 {
		return phone
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}
