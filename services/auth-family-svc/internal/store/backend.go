package store

import (
	"database/sql"

	"github.com/baobao/auth-family-svc/internal/config"
)

// Backend groups persistence used by HTTP handlers.
type Backend struct {
	Store        Store
	Verification VerificationStore
	DB           *sql.DB
}

// NewBackend wires store and verification from config.
func NewBackend(cfg *config.Config, st Store, db *sql.DB) *Backend {
	return &Backend{
		Store:        st,
		Verification: NewVerificationStore(cfg, db),
		DB:           db,
	}
}

// NewVerificationStore selects memory or postgres verification storage.
func NewVerificationStore(cfg *config.Config, db *sql.DB) VerificationStore {
	if cfg != nil && cfg.StorageBackend == "postgres" && db != nil {
		return NewPostgresVerificationStore(db)
	}
	return NewMemoryVerificationStore()
}

// Close releases the database pool when present.
func (b *Backend) Close() error {
	if b == nil || b.DB == nil {
		return nil
	}
	return b.DB.Close()
}

// Users returns the user store (Store implements UserStore).
func (b *Backend) Users() UserStore {
	if b == nil || b.Store == nil {
		return nil
	}
	return b.Store
}
