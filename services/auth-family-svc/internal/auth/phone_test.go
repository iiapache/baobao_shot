package auth

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/store"
)

type recordingSMS struct {
	mu     sync.Mutex
	codes  []string
	phones []string
}

func (r *recordingSMS) Send(_ context.Context, phone, code string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.phones = append(r.phones, phone)
	r.codes = append(r.codes, code)
	return nil
}

func (r *recordingSMS) lastCode() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.codes) == 0 {
		return ""
	}
	return r.codes[len(r.codes)-1]
}

func newTestPhoneService(t *testing.T, now time.Time) (*PhoneAuthService, *recordingSMS, store.VerificationStore) {
	t.Helper()
	users := store.NewMemoryStore()
	verification := store.NewMemoryVerificationStore()
	sms := &recordingSMS{}
	svc := NewPhoneAuthService(users, verification, sms, newTestTokenService(users), &CodeResolver{provider: "mock"})
	svc.now = func() time.Time { return now }
	return svc, sms, verification
}

func TestSendCodeAndLoginNewUser(t *testing.T) {
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, sms, _ := newTestPhoneService(t, now)

	if err := svc.SendCode(context.Background(), "13800138001", "10.0.0.1"); err != nil {
		t.Fatalf("SendCode: %v", err)
	}
	code := sms.lastCode()
	if len(code) != 6 {
		t.Fatalf("code length = %d", len(code))
	}

	result, err := svc.Login(context.Background(), "13800138001", code, "10.0.0.1", "device-phone-1")
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	if !result.IsNewUser {
		t.Fatal("expected new user")
	}
	if result.User.Phone == nil || *result.User.Phone != "13800138001" {
		t.Fatalf("phone = %v", result.User.Phone)
	}
}

func TestSendCodeResendCooldown60s(t *testing.T) {
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _, _ := newTestPhoneService(t, now)

	if err := svc.SendCode(context.Background(), "13800138001", "10.0.0.1"); err != nil {
		t.Fatalf("first SendCode: %v", err)
	}

	svc.now = func() time.Time { return now.Add(30 * time.Second) }
	if err := svc.SendCode(context.Background(), "13800138001", "10.0.0.1"); err != ErrRateLimited {
		t.Fatalf("second SendCode within 60s: got %v, want ErrRateLimited", err)
	}

	svc.now = func() time.Time { return now.Add(61 * time.Second) }
	if err := svc.SendCode(context.Background(), "13800138001", "10.0.0.1"); err != nil {
		t.Fatalf("third SendCode after cooldown: %v", err)
	}
}

func TestVerificationCodeExpiresAfter5Min(t *testing.T) {
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, sms, _ := newTestPhoneService(t, now)

	if err := svc.SendCode(context.Background(), "13800138003", "10.0.0.3"); err != nil {
		t.Fatal(err)
	}
	code := sms.lastCode()

	svc.now = func() time.Time { return now.Add(5*time.Minute + time.Second) }
	_, err := svc.Login(context.Background(), "13800138003", code, "10.0.0.3", "device-phone-1")
	if err != ErrInvalidCode {
		t.Fatalf("login after expiry: got %v, want ErrInvalidCode", err)
	}
}

func TestSlidingWindowLimiter(t *testing.T) {
	limiter := NewSlidingWindowLimiter()
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	cfg := RateLimitConfig{Window: time.Minute, Max: 3}

	for i := 0; i < 3; i++ {
		if !limiter.Allow("k", now.Add(time.Duration(i)*time.Second), cfg) {
			t.Fatalf("event %d should be allowed", i)
		}
	}
	if limiter.Allow("k", now.Add(3*time.Second), cfg) {
		t.Fatal("4th event within window should be denied")
	}
}
