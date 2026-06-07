package audit

import (
	"fmt"
	"time"

	"github.com/baobao/audit-svc/internal/model"
)

// ErrInvalidTransition is returned when an audit status change is not allowed.
var ErrInvalidTransition = fmt.Errorf("invalid audit status transition")

// CanTransition reports whether from can move to to.
func CanTransition(from, to model.AuditStatus) bool {
	if from == to {
		return true
	}
	switch from {
	case model.AuditStatusPending:
		return to == model.AuditStatusPassed || to == model.AuditStatusRejected
	default:
		return false
	}
}

// ApplyTransition mutates job to the target terminal status.
func ApplyTransition(job *model.AuditJob, to model.AuditStatus, result string, reasons []string, vendor string, now time.Time) error {
	if job == nil {
		return fmt.Errorf("job is nil")
	}
	if !CanTransition(job.Status, to) {
		return fmt.Errorf("%w: %s -> %s", ErrInvalidTransition, job.Status, to)
	}
	job.Status = to
	job.Result = result
	job.Reasons = append([]string(nil), reasons...)
	job.Vendor = vendor
	if to != model.AuditStatusPending {
		completed := now.UTC()
		job.CompletedAt = &completed
	}
	return nil
}
