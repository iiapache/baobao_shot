package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"

	"github.com/baobao/auth-family-svc/internal/store"
)

func makeMockIdentityToken(sub string) string {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"none","typ":"JWT"}`))
	payload, _ := json.Marshal(map[string]string{
		"sub": sub,
		"iss": appleIssuer,
	})
	body := base64.RawURLEncoding.EncodeToString(payload)
	return header + "." + body + "."
}

func TestMockAppleVerifier(t *testing.T) {
	v := MockAppleVerifier{}
	claims, err := v.Verify(context.Background(), makeMockIdentityToken("apple-user-1"))
	if err != nil {
		t.Fatal(err)
	}
	if claims.Sub != "apple-user-1" {
		t.Fatalf("sub = %q, want apple-user-1", claims.Sub)
	}
}

func TestAppleLoginNewUser(t *testing.T) {
	users := store.NewMemoryStore()
	svc := NewService(users, MockAppleVerifier{}, newTestTokenService(users))

	result, err := svc.AppleLogin(context.Background(), AppleLoginInput{
		IdentityToken:     makeMockIdentityToken("apple-new-user"),
		AuthorizationCode: "c-test",
		Nickname:          "豆豆妈",
		Region:            "cn",
		DeviceID:          "device-test-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.IsNewUser {
		t.Fatal("expected isNewUser=true")
	}
	if !strings.HasPrefix(result.UserID, "usr_") {
		t.Fatalf("userId = %q, want usr_ prefix", result.UserID)
	}
	if result.Profile.Nickname != "豆豆妈" {
		t.Fatalf("nickname = %q", result.Profile.Nickname)
	}
	if result.Profile.Consents.ChildData {
		t.Fatal("new user should not have childData consent")
	}
	if result.AccessTokenExpiresIn != AccessTokenTTLSeconds {
		t.Fatalf("access ttl = %d", result.AccessTokenExpiresIn)
	}
	if !strings.Contains(result.AccessToken, ".") {
		t.Fatalf("access token should be JWT, got %q", result.AccessToken)
	}
}

func TestAppleLoginExistingUser(t *testing.T) {
	users := store.NewMemoryStore()
	svc := NewService(users, MockAppleVerifier{}, newTestTokenService(users))

	first, err := svc.AppleLogin(context.Background(), AppleLoginInput{
		IdentityToken:     makeMockIdentityToken("apple-returning"),
		AuthorizationCode: "c-1",
		Nickname:          "首次昵称",
		Region:            "cn",
		DeviceID:          "device-test-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !first.IsNewUser {
		t.Fatal("first login should be new user")
	}

	second, err := svc.AppleLogin(context.Background(), AppleLoginInput{
		IdentityToken:     makeMockIdentityToken("apple-returning"),
		AuthorizationCode: "c-2",
		Nickname:          "忽略昵称",
		Region:            "cn",
		DeviceID:          "device-test-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if second.IsNewUser {
		t.Fatal("second login should be existing user")
	}
	if second.UserID != first.UserID {
		t.Fatalf("userId changed: %s -> %s", first.UserID, second.UserID)
	}
	if second.Profile.Nickname != "首次昵称" {
		t.Fatalf("nickname should remain from first login, got %q", second.Profile.Nickname)
	}
}

func TestAppleLoginDuplicateCreateRace(t *testing.T) {
	users := store.NewMemoryStore()
	svc := NewService(users, MockAppleVerifier{}, newTestTokenService(users))

	sub := "apple-race-user"
	_, err := users.CreateUser(context.Background(), store.CreateUserInput{
		ID:       newUserID(),
		AppleSub: sub,
		Region:   "cn",
		Nickname: "seed",
	})
	if err != nil {
		t.Fatal(err)
	}

	result, err := svc.AppleLogin(context.Background(), AppleLoginInput{
		IdentityToken:     makeMockIdentityToken(sub),
		AuthorizationCode: "c-race",
		Region:            "cn",
		DeviceID:          "device-test-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.IsNewUser {
		t.Fatal("expected existing user after duplicate create")
	}
}

func TestAppleLoginInvalidToken(t *testing.T) {
	svc := NewService(store.NewMemoryStore(), MockAppleVerifier{}, newTestTokenService(store.NewMemoryStore()))
	_, err := svc.AppleLogin(context.Background(), AppleLoginInput{
		IdentityToken:     makeMockIdentityToken(""),
		AuthorizationCode: "c-bad",
		Region:            "cn",
		DeviceID:          "device-test-1",
	})
	if err == nil {
		t.Fatal("expected error for invalid token")
	}
	if !strings.Contains(err.Error(), ErrInvalidAppleToken.Error()) {
		t.Fatalf("unexpected error: %v", err)
	}
}
