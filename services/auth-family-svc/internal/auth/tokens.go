package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	AccessTokenTTLSeconds  = 3600
	RefreshTokenTTLSeconds = 2592000
	maxFamiliesInClaim       = 5

	tokenTypeAccess  = "access"
	tokenTypeRefresh = "refresh"
)

// TokenPair holds issued access and refresh tokens.
type TokenPair struct {
	AccessToken           string
	AccessTokenExpiresIn  int
	RefreshToken          string
	RefreshTokenExpiresIn int
}

// FamilyClaim is a family membership entry embedded in JWT.
type FamilyClaim struct {
	FamilyID string `json:"familyId"`
	Role     string `json:"role"`
}

// SessionClaims are baobao session JWT claims.
type SessionClaims struct {
	jwt.RegisteredClaims
	Region   string        `json:"region"`
	Families []FamilyClaim `json:"families"`
	Dev      string        `json:"dev"`
	Typ      string        `json:"typ"`
}

// TokenIssuer signs and verifies HS256 session tokens.
type TokenIssuer struct {
	secret []byte
	now    func() time.Time
}

// NewTokenIssuer creates a JWT issuer with the configured signing secret.
func NewTokenIssuer(secret string) *TokenIssuer {
	return &TokenIssuer{
		secret: []byte(secret),
		now:    time.Now,
	}
}

// IssueTokenInput describes a new token pair request.
type IssueTokenInput struct {
	UserID   string
	Region   string
	DeviceID string
	Families []FamilyClaim
}

// Issue creates a fresh access + refresh token pair.
func (i *TokenIssuer) Issue(in IssueTokenInput) (TokenPair, error) {
	if in.UserID == "" {
		return TokenPair{}, errors.New("user id required")
	}
	if in.Region == "" {
		return TokenPair{}, errors.New("region required")
	}
	if in.DeviceID == "" {
		return TokenPair{}, errors.New("device id required")
	}

	now := i.now().UTC()
	accessExp := now.Add(time.Duration(AccessTokenTTLSeconds) * time.Second)
	refreshExp := now.Add(time.Duration(RefreshTokenTTLSeconds) * time.Second)

	families := in.Families
	if len(families) > maxFamiliesInClaim {
		families = families[:maxFamiliesInClaim]
	}

	accessJTI := newJTI()
	accessClaims := SessionClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   in.UserID,
			ID:        accessJTI,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(accessExp),
		},
		Region:   in.Region,
		Families: families,
		Dev:      in.DeviceID,
		Typ:      tokenTypeAccess,
	}
	accessToken, err := i.sign(accessClaims)
	if err != nil {
		return TokenPair{}, err
	}

	refreshJTI := newJTI()
	refreshClaims := SessionClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   in.UserID,
			ID:        refreshJTI,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(refreshExp),
		},
		Region:   in.Region,
		Families: families,
		Dev:      in.DeviceID,
		Typ:      tokenTypeRefresh,
	}
	refreshToken, err := i.sign(refreshClaims)
	if err != nil {
		return TokenPair{}, err
	}

	return TokenPair{
		AccessToken:           accessToken,
		AccessTokenExpiresIn:  AccessTokenTTLSeconds,
		RefreshToken:          refreshToken,
		RefreshTokenExpiresIn: RefreshTokenTTLSeconds,
	}, nil
}

// ParseAccess validates an access token and returns its claims.
func (i *TokenIssuer) ParseAccess(token string) (*SessionClaims, error) {
	claims, err := i.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.Typ != tokenTypeAccess {
		return nil, ErrRefreshInvalid
	}
	return claims, nil
}

// ParseRefresh validates a refresh token and returns its claims.
func (i *TokenIssuer) ParseRefresh(token string) (*SessionClaims, error) {
	claims, err := i.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.Typ != tokenTypeRefresh {
		return nil, ErrRefreshInvalid
	}
	return claims, nil
}

func (i *TokenIssuer) parse(token string) (*SessionClaims, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, ErrRefreshInvalid
	}

	parsed, err := jwt.ParseWithClaims(token, &SessionClaims{}, func(t *jwt.Token) (any, error) {
		if t.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return i.secret, nil
	})
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrRefreshInvalid
	}

	claims, ok := parsed.Claims.(*SessionClaims)
	if !ok || !parsed.Valid {
		return nil, ErrRefreshInvalid
	}
	if claims.Subject == "" || claims.ID == "" {
		return nil, ErrRefreshInvalid
	}
	return claims, nil
}

func (i *TokenIssuer) sign(claims SessionClaims) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(i.secret)
}

func newJTI() string {
	return "jti_" + strings.ReplaceAll(uuid.NewString(), "-", "")
}

// TokenService orchestrates issuance, refresh rotation, and logout revocation.
type TokenService struct {
	issuer     *TokenIssuer
	revocation store.RevocationStore
	families   store.FamilyStore
	now        func() time.Time
}

// NewTokenService wires token issuance with revocation and family lookups.
func NewTokenService(issuer *TokenIssuer, revocation store.RevocationStore, families store.FamilyStore) *TokenService {
	return &TokenService{
		issuer:     issuer,
		revocation: revocation,
		families:   families,
		now:        time.Now,
	}
}

// IssueForUser loads family memberships and issues tokens.
func (s *TokenService) IssueForUser(ctx context.Context, userID, region, deviceID string) (TokenPair, error) {
	families, err := s.loadFamilyClaims(ctx, userID)
	if err != nil {
		return TokenPair{}, err
	}
	return s.issuer.Issue(IssueTokenInput{
		UserID:   userID,
		Region:   region,
		DeviceID: deviceID,
		Families: families,
	})
}

// Refresh rotates refresh tokens and revokes the previous refresh JTI.
func (s *TokenService) Refresh(ctx context.Context, refreshToken, deviceID string) (TokenPair, error) {
	claims, err := s.issuer.ParseRefresh(refreshToken)
	if err != nil {
		return TokenPair{}, err
	}

	revoked, err := s.revocation.IsRevoked(ctx, claims.ID)
	if err != nil {
		return TokenPair{}, err
	}
	if revoked {
		return TokenPair{}, ErrRefreshInvalid
	}

	if deviceID == "" || claims.Dev != deviceID {
		return TokenPair{}, ErrDeviceMismatch
	}

	ttl := time.Until(claims.ExpiresAt.Time)
	if ttl <= 0 {
		return TokenPair{}, ErrRefreshInvalid
	}
	if err := s.revocation.Revoke(ctx, claims.ID, ttl); err != nil {
		return TokenPair{}, err
	}

	families, err := s.loadFamilyClaims(ctx, claims.Subject)
	if err != nil {
		return TokenPair{}, err
	}

	return s.issuer.Issue(IssueTokenInput{
		UserID:   claims.Subject,
		Region:   claims.Region,
		DeviceID: deviceID,
		Families: families,
	})
}

// Logout revokes the current access token until its original expiry.
func (s *TokenService) Logout(ctx context.Context, accessToken string) error {
	claims, err := s.issuer.ParseAccess(accessToken)
	if err != nil {
		return err
	}

	revoked, err := s.revocation.IsRevoked(ctx, claims.ID)
	if err != nil {
		return err
	}
	if revoked {
		return ErrTokenRevoked
	}

	ttl := time.Until(claims.ExpiresAt.Time)
	if ttl <= 0 {
		return ErrTokenExpired
	}
	return s.revocation.Revoke(ctx, claims.ID, ttl)
}

// ValidateAccess checks signature, expiry, and revocation for middleware.
func (s *TokenService) ValidateAccess(ctx context.Context, accessToken string) (*SessionClaims, error) {
	claims, err := s.issuer.ParseAccess(accessToken)
	if err != nil {
		return nil, err
	}

	revoked, err := s.revocation.IsRevoked(ctx, claims.ID)
	if err != nil {
		return nil, err
	}
	if revoked {
		return nil, ErrTokenRevoked
	}
	return claims, nil
}

func (s *TokenService) loadFamilyClaims(ctx context.Context, userID string) ([]FamilyClaim, error) {
	if s.families == nil {
		return []FamilyClaim{}, nil
	}
	summaries, err := s.families.ListUserFamilies(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]FamilyClaim, 0, len(summaries))
	for _, item := range summaries {
		out = append(out, FamilyClaim{
			FamilyID: item.Family.ID,
			Role:     string(item.Role),
		})
		if len(out) >= maxFamiliesInClaim {
			break
		}
	}
	return out, nil
}
