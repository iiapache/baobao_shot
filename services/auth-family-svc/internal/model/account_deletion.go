package model

import "time"

// AccountDeletion tracks a pending or completed account deletion request.
type AccountDeletion struct {
	UserID      string
	RequestedAt time.Time
	ScheduledAt time.Time
	CancelledAt *time.Time
	CompletedAt *time.Time
}

// IsPending reports whether the deletion is active and within the grace window.
func (d *AccountDeletion) IsPending(now time.Time) bool {
	if d == nil || d.CancelledAt != nil || d.CompletedAt != nil {
		return false
	}
	return !now.After(d.ScheduledAt)
}

// DataExportRequest tracks a user-initiated data export job.
type DataExportRequest struct {
	ID          string
	UserID      string
	Status      string
	RequestedAt time.Time
	CompletedAt *time.Time
}
