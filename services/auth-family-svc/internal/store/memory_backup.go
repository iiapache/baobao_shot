package store

import (
	"context"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *MemoryStore) UpsertBackupProvider(_ context.Context, in UpsertBackupProviderInput) (*model.BackupProvider, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := backupUserKindKey(in.UserID, in.Kind)
	now := in.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}

	if existingID, ok := s.backupByUserKind[key]; ok {
		existing := s.backupProviders[existingID]
		existing.AccessToken = in.AccessToken
		existing.RefreshToken = cloneStringPtr(in.RefreshToken)
		existing.ExpiresAt = cloneTimePtr(in.ExpiresAt)
		existing.ProviderAccountID = cloneStringPtr(in.ProviderAccountID)
		existing.Metadata = cloneMetadataMap(in.Metadata)
		existing.Status = in.Status
		existing.UpdatedAt = now
		return cloneBackupProvider(existing), nil
	}

	provider := &model.BackupProvider{
		ID:                in.ID,
		UserID:            in.UserID,
		Kind:              in.Kind,
		AccessToken:       in.AccessToken,
		RefreshToken:      cloneStringPtr(in.RefreshToken),
		ExpiresAt:         cloneTimePtr(in.ExpiresAt),
		ProviderAccountID: cloneStringPtr(in.ProviderAccountID),
		Metadata:          cloneMetadataMap(in.Metadata),
		Status:            in.Status,
		CreatedAt:         now,
		UpdatedAt:         now,
	}
	s.backupProviders[in.ID] = provider
	s.backupByUserKind[key] = in.ID
	return cloneBackupProvider(provider), nil
}

func (s *MemoryStore) ListBackupProviders(_ context.Context, userID string) ([]model.BackupProvider, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]model.BackupProvider, 0)
	for _, provider := range s.backupProviders {
		if provider.UserID != userID || provider.Status != model.BackupProviderStatusActive {
			continue
		}
		items = append(items, *cloneBackupProvider(provider))
	}
	return items, nil
}

func (s *MemoryStore) DeleteBackupProvider(_ context.Context, userID, providerID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	provider, ok := s.backupProviders[providerID]
	if !ok || provider.UserID != userID {
		return ErrNotFound
	}
	delete(s.backupProviders, providerID)
	delete(s.backupByUserKind, backupUserKindKey(userID, provider.Kind))
	return nil
}

func (s *MemoryStore) GetBackupStatus(_ context.Context, userID string) (*model.BackupStatus, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	status, ok := s.backupStatus[userID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneBackupStatus(status), nil
}

func (s *MemoryStore) UpsertBackupStatus(_ context.Context, in UpsertBackupStatusInput) (*model.BackupStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := in.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}

	status, ok := s.backupStatus[in.UserID]
	if !ok {
		status = &model.BackupStatus{UserID: in.UserID, FailureCount: 0}
		s.backupStatus[in.UserID] = status
	}

	attemptedAt := in.AttemptedAt.UTC()
	status.LastAttemptAt = &attemptedAt
	status.UpdatedAt = now

	if in.Success {
		status.LastSuccessAt = &attemptedAt
		status.FailureCount = 0
		status.LastErrorCode = nil
	} else {
		status.FailureCount++
		status.LastErrorCode = cloneStringPtr(in.ErrorCode)
	}

	return cloneBackupStatus(status), nil
}

func backupUserKindKey(userID, kind string) string {
	return fmt.Sprintf("%s|%s", userID, kind)
}

func cloneBackupProvider(src *model.BackupProvider) *model.BackupProvider {
	if src == nil {
		return nil
	}
	dst := *src
	dst.RefreshToken = cloneStringPtr(src.RefreshToken)
	dst.ExpiresAt = cloneTimePtr(src.ExpiresAt)
	dst.ProviderAccountID = cloneStringPtr(src.ProviderAccountID)
	dst.Metadata = cloneMetadataMap(src.Metadata)
	return &dst
}

func cloneBackupStatus(src *model.BackupStatus) *model.BackupStatus {
	if src == nil {
		return nil
	}
	dst := *src
	dst.LastSuccessAt = cloneTimePtr(src.LastSuccessAt)
	dst.LastAttemptAt = cloneTimePtr(src.LastAttemptAt)
	dst.LastErrorCode = cloneStringPtr(src.LastErrorCode)
	return &dst
}

func cloneStringPtr(src *string) *string {
	if src == nil {
		return nil
	}
	v := *src
	return &v
}

func cloneMetadataMap(src map[string]string) map[string]string {
	if len(src) == 0 {
		return map[string]string{}
	}
	dst := make(map[string]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
