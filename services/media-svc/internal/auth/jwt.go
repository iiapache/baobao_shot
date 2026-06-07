package auth

import (
	"errors"
	"fmt"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

const tokenTypeAccess = "access"

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrExpiredToken = errors.New("token expired")
)

// SessionClaims mirrors auth-family-svc access token claims.
type SessionClaims struct {
	jwt.RegisteredClaims
	Region string `json:"region"`
	Typ    string `json:"typ"`
}

// Validator verifies HS256 access tokens issued by auth-family-svc.
type Validator struct {
	secret []byte
}

// NewValidator creates a JWT validator with the shared signing secret.
func NewValidator(secret string) *Validator {
	return &Validator{secret: []byte(secret)}
}

// ParseAccess validates an access token and returns claims.
func (v *Validator) ParseAccess(token string) (*SessionClaims, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, ErrInvalidToken
	}

	parsed, err := jwt.ParseWithClaims(token, &SessionClaims{}, func(t *jwt.Token) (any, error) {
		if t.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return v.secret, nil
	})
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrExpiredToken
		}
		return nil, ErrInvalidToken
	}

	claims, ok := parsed.Claims.(*SessionClaims)
	if !ok || !parsed.Valid {
		return nil, ErrInvalidToken
	}
	if claims.Subject == "" || claims.Typ != tokenTypeAccess {
		return nil, ErrInvalidToken
	}
	return claims, nil
}
