package store

import (
	"context"
	"fmt"

	"github.com/baobao/auth-family-svc/internal/crypto/seal"
	"github.com/baobao/auth-family-svc/internal/model"
)

// EncryptingBackupStore wraps a BackupStore and encrypts OAuth tokens at rest.
type EncryptingBackupStore struct {
	inner  BackupStore
	sealer *seal.Sealer
}

// NewEncryptingBackupStore creates a BackupStore that seals access and refresh tokens.
func NewEncryptingBackupStore(inner BackupStore, sealer *seal.Sealer) *EncryptingBackupStore {
	return &EncryptingBackupStore{inner: inner, sealer: sealer}
}

func (s *EncryptingBackupStore) UpsertBackupProvider(ctx context.Context, in UpsertBackupProviderInput) (*model.BackupProvider, error) {
	encIn := in
	var err error
	encIn.AccessToken, err = s.sealer.Seal(in.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("seal access token: %w", err)
	}
	if in.RefreshToken != nil {
		sealed, err := s.sealer.Seal(*in.RefreshToken)
		if err != nil {
			return nil, fmt.Errorf("seal refresh token: %w", err)
		}
		encIn.RefreshToken = &sealed
	}

	out, err := s.inner.UpsertBackupProvider(ctx, encIn)
	if err != nil {
		return nil, err
	}
	return decryptBackupProvider(s.sealer, out)
}

func (s *EncryptingBackupStore) ListBackupProviders(ctx context.Context, userID string) ([]model.BackupProvider, error) {
	items, err := s.inner.ListBackupProviders(ctx, userID)
	if err != nil {
		return nil, err
	}
	for i := range items {
		decrypted, err := decryptBackupProvider(s.sealer, &items[i])
		if err != nil {
			return nil, err
		}
		items[i] = *decrypted
	}
	return items, nil
}

func (s *EncryptingBackupStore) DeleteBackupProvider(ctx context.Context, userID, providerID string) error {
	return s.inner.DeleteBackupProvider(ctx, userID, providerID)
}

func (s *EncryptingBackupStore) GetBackupStatus(ctx context.Context, userID string) (*model.BackupStatus, error) {
	return s.inner.GetBackupStatus(ctx, userID)
}

func (s *EncryptingBackupStore) UpsertBackupStatus(ctx context.Context, in UpsertBackupStatusInput) (*model.BackupStatus, error) {
	return s.inner.UpsertBackupStatus(ctx, in)
}

func decryptBackupProvider(sealer *seal.Sealer, provider *model.BackupProvider) (*model.BackupProvider, error) {
	if provider == nil {
		return nil, nil
	}
	out := *provider
	var err error
	out.AccessToken, err = sealer.Unseal(provider.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("unseal access token: %w", err)
	}
	if provider.RefreshToken != nil {
		plain, err := sealer.Unseal(*provider.RefreshToken)
		if err != nil {
			return nil, fmt.Errorf("unseal refresh token: %w", err)
		}
		out.RefreshToken = &plain
	}
	return &out, nil
}
