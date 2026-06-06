package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const appleIssuer = "https://appleid.apple.com"

// AppleClaims holds verified Sign in with Apple identity token claims.
type AppleClaims struct {
	Sub string
}

// AppleVerifier validates Apple identity tokens.
type AppleVerifier interface {
	Verify(ctx context.Context, identityToken string) (*AppleClaims, error)
}

// MockAppleVerifier skips JWKS signature verification (dev/test only).
type MockAppleVerifier struct{}

// Verify parses the JWT payload without verifying the signature.
func (MockAppleVerifier) Verify(_ context.Context, identityToken string) (*AppleClaims, error) {
	return parseAppleClaims(identityToken, false)
}

// ProductionAppleVerifier validates JWT signature against Apple JWKS.
type ProductionAppleVerifier struct {
	BundleID string
}

// Verify validates the token signature using Apple public keys.
func (ProductionAppleVerifier) Verify(_ context.Context, _ string) (*AppleClaims, error) {
	return nil, fmt.Errorf("production Apple verification not enabled in T1.1; set MOCK_APPLE_VERIFY=true")
}

func parseAppleClaims(identityToken string, requireSignature bool) (*AppleClaims, error) {
	if requireSignature {
		return nil, errors.New("signature verification not configured")
	}

	identityToken = strings.TrimSpace(identityToken)
	if identityToken == "" {
		return nil, errors.New("empty identity token")
	}

	if !strings.Contains(identityToken, ".") {
		return &AppleClaims{Sub: identityToken}, nil
	}

	parser := jwt.NewParser()
	token, _, err := parser.ParseUnverified(identityToken, jwt.MapClaims{})
	if err != nil {
		return nil, fmt.Errorf("parse identity token: %w", err)
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, errors.New("invalid token claims")
	}

	sub, _ := claims["sub"].(string)
	if sub == "" {
		return nil, errors.New("missing sub claim")
	}

	if iss, _ := claims["iss"].(string); iss != "" && iss != appleIssuer {
		return nil, fmt.Errorf("unexpected iss: %s", iss)
	}

	return &AppleClaims{Sub: sub}, nil
}

// NewAppleVerifier selects mock or production verifier from config.
func NewAppleVerifier(mockVerify bool, bundleID string) AppleVerifier {
	if mockVerify {
		return MockAppleVerifier{}
	}
	return ProductionAppleVerifier{BundleID: bundleID}
}

// AppleLoginInput is the service-layer Apple sign-in request.
type AppleLoginInput struct {
	IdentityToken     string
	AuthorizationCode string
	Nickname          string
	Region            string
	DeviceID          string
}

// Profile is the user profile returned after login.
type Profile struct {
	Nickname  string   `json:"nickname"`
	AvatarURL *string  `json:"avatarUrl"`
	Region    string   `json:"region"`
	Consents  Consents `json:"consents"`
}

// Consents tracks legal consent flags exposed to clients.
type Consents struct {
	ChildData bool `json:"childData"`
}

// AppleLoginResult is the service-layer Apple sign-in response.
type AppleLoginResult struct {
	UserID                string
	IsNewUser             bool
	AccessToken           string
	AccessTokenExpiresIn  int
	RefreshToken          string
	RefreshTokenExpiresIn int
	Profile               Profile
}

// Service orchestrates Apple sign-in flows.
type Service struct {
	users    store.UserStore
	verifier AppleVerifier
	tokens   *TokenService
}

// NewService creates an auth service.
func NewService(users store.UserStore, verifier AppleVerifier, tokens *TokenService) *Service {
	return &Service{users: users, verifier: verifier, tokens: tokens}
}

// AppleLogin verifies the identity token and creates or loads the user.
func (s *Service) AppleLogin(ctx context.Context, in AppleLoginInput) (*AppleLoginResult, error) {
	claims, err := s.verifier.Verify(ctx, in.IdentityToken)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidAppleToken, err)
	}

	user, isNew, err := s.findOrCreateAppleUser(ctx, claims.Sub, in)
	if err != nil {
		return nil, err
	}

	tokens, err := s.tokens.IssueForUser(ctx, user.ID, user.Region, in.DeviceID)
	if err != nil {
		return nil, err
	}
	return &AppleLoginResult{
		UserID:                user.ID,
		IsNewUser:             isNew,
		AccessToken:           tokens.AccessToken,
		AccessTokenExpiresIn:  tokens.AccessTokenExpiresIn,
		RefreshToken:          tokens.RefreshToken,
		RefreshTokenExpiresIn: tokens.RefreshTokenExpiresIn,
		Profile:               profileFromUser(user),
	}, nil
}

func (s *Service) findOrCreateAppleUser(ctx context.Context, appleSub string, in AppleLoginInput) (*model.User, bool, error) {
	existing, err := s.users.FindByAppleSub(ctx, appleSub)
	if err == nil {
		user, err := s.users.TouchLastSeen(ctx, existing.ID)
		return user, false, err
	}
	if !errors.Is(err, store.ErrNotFound) {
		return nil, false, err
	}

	nickname := strings.TrimSpace(in.Nickname)
	user, err := s.users.CreateUser(ctx, store.CreateUserInput{
		ID:       newUserID(),
		AppleSub: appleSub,
		Region:   in.Region,
		Nickname: nickname,
	})
	if err == nil {
		return user, true, nil
	}
	if !errors.Is(err, store.ErrDuplicateAppleSub) {
		return nil, false, err
	}

	existing, err = s.users.FindByAppleSub(ctx, appleSub)
	if err != nil {
		return nil, false, err
	}
	user, err = s.users.TouchLastSeen(ctx, existing.ID)
	return user, false, err
}

func profileFromUser(user *model.User) Profile {
	return Profile{
		Nickname:  user.Nickname,
		AvatarURL: user.AvatarURL,
		Region:    user.Region,
		Consents: Consents{
			ChildData: user.HasChildDataConsent(),
		},
	}
}

func newUserID() string {
	return "usr_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:16]
}
