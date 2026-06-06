package backup

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/google/uuid"
)

// BindInput holds OAuth token metadata for binding a backup provider.
type BindInput struct {
	Kind              string
	AccessToken       string
	RefreshToken      *string
	ExpiresAt         *time.Time
	ProviderAccountID *string
	Metadata          map[string]string
}

// ReportStatusInput holds a client-reported backup attempt outcome.
type ReportStatusInput struct {
	Success     bool
	AttemptedAt time.Time
	ErrorCode   *string
}

// Service manages backup provider bindings and status reporting.
type Service struct {
	store store.BackupStore
	now   func() time.Time
}

// NewService creates a backup credential service.
func NewService(s store.BackupStore) *Service {
	return &Service{store: s, now: func() time.Time { return time.Now().UTC() }}
}

// BindProvider upserts OAuth token metadata for a backup destination.
func (s *Service) BindProvider(ctx context.Context, userID string, in BindInput) (*model.BackupProvider, error) {
	kind := strings.TrimSpace(in.Kind)
	if !isValidKind(kind) {
		return nil, ErrInvalidKind
	}
	if kind == model.BackupProviderKindBaiduPan && strings.TrimSpace(in.AccessToken) == "" {
		return nil, ErrTokenRequired
	}

	now := s.now()
	provider, err := s.store.UpsertBackupProvider(ctx, store.UpsertBackupProviderInput{
		ID:                "bkp_" + uuid.NewString()[:12],
		UserID:            userID,
		Kind:              kind,
		AccessToken:       strings.TrimSpace(in.AccessToken),
		RefreshToken:      in.RefreshToken,
		ExpiresAt:         in.ExpiresAt,
		ProviderAccountID: in.ProviderAccountID,
		Metadata:          cloneMetadata(in.Metadata),
		Status:            model.BackupProviderStatusActive,
		Now:               now,
	})
	if err != nil {
		return nil, err
	}
	return provider, nil
}

// ListProviders returns active provider bindings without token secrets.
func (s *Service) ListProviders(ctx context.Context, userID string) ([]model.BackupProvider, error) {
	return s.store.ListBackupProviders(ctx, userID)
}

// UnbindProvider removes a provider binding owned by the user.
func (s *Service) UnbindProvider(ctx context.Context, userID, providerID string) error {
	err := s.store.DeleteBackupProvider(ctx, userID, providerID)
	if errors.Is(err, store.ErrNotFound) {
		return ErrNotFound
	}
	return err
}

// GetStatus returns aggregate backup status for the user.
func (s *Service) GetStatus(ctx context.Context, userID string) (*model.BackupStatus, error) {
	status, err := s.store.GetBackupStatus(ctx, userID)
	if errors.Is(err, store.ErrNotFound) {
		return &model.BackupStatus{UserID: userID, FailureCount: 0, UpdatedAt: s.now()}, nil
	}
	return status, err
}

// ReportStatus records the latest client-side backup attempt.
func (s *Service) ReportStatus(ctx context.Context, userID string, in ReportStatusInput) (*model.BackupStatus, error) {
	if in.AttemptedAt.IsZero() {
		in.AttemptedAt = s.now()
	}
	return s.store.UpsertBackupStatus(ctx, store.UpsertBackupStatusInput{
		UserID:      userID,
		Success:     in.Success,
		AttemptedAt: in.AttemptedAt.UTC(),
		ErrorCode:   in.ErrorCode,
		Now:         s.now(),
	})
}

func isValidKind(kind string) bool {
	switch kind {
	case model.BackupProviderKindICloud, model.BackupProviderKindBaiduPan, model.BackupProviderKindPhotos:
		return true
	default:
		return false
	}
}

func cloneMetadata(src map[string]string) map[string]string {
	if len(src) == 0 {
		return map[string]string{}
	}
	dst := make(map[string]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
