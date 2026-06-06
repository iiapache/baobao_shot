package auth

import (
	"github.com/baobao/auth-family-svc/internal/store"
)

func newTestTokenService(st store.FamilyStore) *TokenService {
	issuer := NewTokenIssuer("test-signing-secret")
	revocation := store.NewMemoryRevocationStore()
	return NewTokenService(issuer, revocation, st)
}
