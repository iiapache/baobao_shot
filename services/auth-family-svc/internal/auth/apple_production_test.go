package auth

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var errJWKSKeyNotFound = errors.New("jwks key not found")

type staticJWKSProvider struct {
	keys map[string]*rsa.PublicKey
}

func (p staticJWKSProvider) PublicKey(_ context.Context, kid string) (*rsa.PublicKey, error) {
	key, ok := p.keys[kid]
	if !ok {
		return nil, errJWKSKeyNotFound
	}
	return key, nil
}

func TestProductionAppleVerifierValidToken(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}

	const kid = "test-kid"
	const bundleID = "com.babycamera.app"
	const sub = "001234.abcdef1234567890.1234"

	jwksServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := base64.RawURLEncoding.EncodeToString(privateKey.PublicKey.N.Bytes())
		e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(privateKey.PublicKey.E)).Bytes())
		_ = json.NewEncoder(w).Encode(appleJWKSResponse{
			Keys: []appleJWK{{
				Kty: "RSA",
				Kid: kid,
				Use: "sig",
				Alg: "RS256",
				N:   n,
				E:   e,
			}},
		})
	}))
	defer jwksServer.Close()

	client := &AppleJWKSClient{
		httpClient: jwksServer.Client(),
		jwksURL:    jwksServer.URL,
		keys:       make(map[string]*rsa.PublicKey),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": appleIssuer,
		"sub": sub,
		"aud": bundleID,
		"exp": time.Now().Add(time.Hour).Unix(),
		"iat": time.Now().Unix(),
	})
	token.Header["kid"] = kid
	signed, err := token.SignedString(privateKey)
	if err != nil {
		t.Fatal(err)
	}

	verifier := &ProductionAppleVerifier{BundleID: bundleID, JWKS: client}
	claims, err := verifier.Verify(context.Background(), signed)
	if err != nil {
		t.Fatal(err)
	}
	if claims.Sub != sub {
		t.Fatalf("sub = %q, want %q", claims.Sub, sub)
	}
}

func TestProductionAppleVerifierRejectsWrongAudience(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}

	const kid = "test-kid"
	provider := staticJWKSProvider{keys: map[string]*rsa.PublicKey{kid: &privateKey.PublicKey}}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": appleIssuer,
		"sub": "user-1",
		"aud": "com.other.app",
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	token.Header["kid"] = kid
	signed, err := token.SignedString(privateKey)
	if err != nil {
		t.Fatal(err)
	}

	verifier := &ProductionAppleVerifier{BundleID: "com.babycamera.app", JWKS: provider}
	_, err = verifier.Verify(context.Background(), signed)
	if err == nil {
		t.Fatal("expected audience mismatch error")
	}
}

func TestProductionAppleVerifierRequiresBundleID(t *testing.T) {
	verifier := &ProductionAppleVerifier{JWKS: staticJWKSProvider{}}
	_, err := verifier.Verify(context.Background(), "token")
	if err == nil {
		t.Fatal("expected bundle id error")
	}
}

func TestAppleJWKSClientRefresh(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	const kid = "refresh-kid"

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := base64.RawURLEncoding.EncodeToString(privateKey.PublicKey.N.Bytes())
		e := base64.RawURLEncoding.EncodeToString(big.NewInt(int64(privateKey.PublicKey.E)).Bytes())
		_ = json.NewEncoder(w).Encode(appleJWKSResponse{
			Keys: []appleJWK{{
				Kty: "RSA",
				Kid: kid,
				Alg: "RS256",
				N:   n,
				E:   e,
			}},
		})
	}))
	defer server.Close()

	client := &AppleJWKSClient{
		httpClient: server.Client(),
		jwksURL:    server.URL,
		keys:       make(map[string]*rsa.PublicKey),
	}

	pub, err := client.PublicKey(context.Background(), kid)
	if err != nil {
		t.Fatal(err)
	}
	if pub.N.Cmp(privateKey.PublicKey.N) != 0 {
		t.Fatal("public key mismatch after refresh")
	}
}
