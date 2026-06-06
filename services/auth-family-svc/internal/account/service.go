package account

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/google/uuid"
)

// DeletionResult is returned after requesting account deletion.
type DeletionResult struct {
	RequestedAt  time.Time
	ScheduledAt  time.Time
	RevokeBefore time.Time
}

// CancelResult is returned after cancelling a pending deletion.
type CancelResult struct {
	CancelledAt time.Time
	Restored    bool
}

// ExportResult is returned after submitting a data export request.
type ExportResult struct {
	ExportID    string
	Status      string
	RequestedAt time.Time
}

// Service manages account deletion and data export request flows.
type Service struct {
	store store.AccountStore
	now   func() time.Time
}

// NewService creates an account lifecycle service.
func NewService(st store.AccountStore) *Service {
	return &Service{store: st, now: time.Now}
}

// RequestDeletion soft-deletes the account and schedules hard deletion after the grace period.
// Idempotent: an existing pending request returns the same schedule.
func (s *Service) RequestDeletion(ctx context.Context, userID string) (*DeletionResult, error) {
	now := s.now().UTC()

	if _, err := s.store.FindUserIncludingDeleted(ctx, userID); err != nil {
		if errorsIsNotFound(err) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	existing, err := s.store.GetDeletion(ctx, userID)
	if err != nil && !errorsIsNotFound(err) {
		return nil, err
	}
	if existing != nil {
		if existing.CompletedAt != nil {
			return nil, ErrAlreadyHardDeleted
		}
		if existing.CancelledAt == nil {
			return toDeletionResult(existing), nil
		}
	}

	scheduledAt := now.Add(DeletionGracePeriod)
	record, err := s.store.UpsertDeletion(ctx, userID, now, scheduledAt)
	if err != nil {
		return nil, err
	}
	if err := s.store.SoftDeleteUser(ctx, userID, now); err != nil {
		return nil, err
	}
	return toDeletionResult(record), nil
}

// CancelDeletion revokes a pending deletion within the grace period and restores the account.
func (s *Service) CancelDeletion(ctx context.Context, userID string) (*CancelResult, error) {
	now := s.now().UTC()

	record, err := s.store.GetDeletion(ctx, userID)
	if err != nil {
		if errorsIsNotFound(err) {
			return nil, ErrDeletionNotPending
		}
		return nil, err
	}
	if record.CompletedAt != nil {
		return nil, ErrAlreadyHardDeleted
	}
	if record.CancelledAt != nil {
		return nil, ErrDeletionNotPending
	}
	if now.After(record.ScheduledAt) {
		return nil, ErrDeletionExpired
	}

	cancelled, err := s.store.CancelDeletion(ctx, userID, now)
	if err != nil {
		return nil, err
	}
	if err := s.store.RestoreUser(ctx, userID); err != nil {
		return nil, err
	}
	return &CancelResult{
		CancelledAt: cancelledAt(cancelled),
		Restored:    true,
	}, nil
}

// RequestExport creates a data export job request (async processing is out of scope for T1.4).
// Idempotent: returns the existing pending export when one is already in flight.
func (s *Service) RequestExport(ctx context.Context, userID string) (*ExportResult, error) {
	now := s.now().UTC()

	if _, err := s.store.FindUserIncludingDeleted(ctx, userID); err != nil {
		if errorsIsNotFound(err) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	if pending, err := s.store.GetPendingExport(ctx, userID); err == nil && pending != nil {
		return toExportResult(pending), nil
	} else if err != nil && !errorsIsNotFound(err) {
		return nil, err
	}

	exportID := "exp_" + uuid.NewString()[:12]
	record, err := s.store.CreateExportRequest(ctx, userID, exportID, now)
	if err != nil {
		return nil, err
	}
	return toExportResult(record), nil
}

// ProcessDueHardDeletions executes hard deletion for accounts past scheduled_at.
// Returns the number of accounts processed. Downstream feed/credit cleanup is stubbed.
func (s *Service) ProcessDueHardDeletions(ctx context.Context) (int, error) {
	now := s.now().UTC()
	due, err := s.store.ListDueDeletions(ctx, now)
	if err != nil {
		return 0, err
	}

	processed := 0
	for _, item := range due {
		if err := s.hardDeleteAccount(ctx, item.UserID, now); err != nil {
			slog.Error("hard delete account failed", "userId", item.UserID, "error", err)
			continue
		}
		processed++
	}
	return processed, nil
}

func (s *Service) hardDeleteAccount(ctx context.Context, userID string, now time.Time) error {
	// TODO(T1.4+): invoke feed-svc and credit-sub-ad-svc cleanup hooks.
	slog.Info("account hard delete stub", "userId", userID, "note", "feed/credit cleanup pending")
	if err := s.store.CompleteHardDeletion(ctx, userID, now); err != nil {
		return fmt.Errorf("complete hard deletion: %w", err)
	}
	return nil
}

func toDeletionResult(d *model.AccountDeletion) *DeletionResult {
	return &DeletionResult{
		RequestedAt:  d.RequestedAt.UTC(),
		ScheduledAt:  d.ScheduledAt.UTC(),
		RevokeBefore: d.ScheduledAt.UTC(),
	}
}

func toExportResult(r *model.DataExportRequest) *ExportResult {
	return &ExportResult{
		ExportID:    r.ID,
		Status:      r.Status,
		RequestedAt: r.RequestedAt.UTC(),
	}
}

func cancelledAt(d *model.AccountDeletion) time.Time {
	if d.CancelledAt != nil {
		return d.CancelledAt.UTC()
	}
	return time.Time{}
}

func errorsIsNotFound(err error) bool {
	return errors.Is(err, store.ErrNotFound) || errors.Is(err, ErrUserNotFound)
}
