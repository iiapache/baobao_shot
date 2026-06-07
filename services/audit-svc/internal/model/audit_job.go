package model

import "time"

// AuditKind identifies the audit pipeline category.
type AuditKind string

const (
	AuditKindInput  AuditKind = "input"
	AuditKindOutput AuditKind = "output"
	AuditKindUGC    AuditKind = "ugc"
)

// AuditStatus is the audit job state machine value.
type AuditStatus string

const (
	AuditStatusPending  AuditStatus = "pending"
	AuditStatusPassed   AuditStatus = "passed"
	AuditStatusRejected AuditStatus = "rejected"
)

// AuditJob is a persisted content audit record.
type AuditJob struct {
	ID          string
	Kind        AuditKind
	TargetRef   string
	Status      AuditStatus
	Result      string
	Reasons     []string
	Vendor      string
	Region      string
	CreatedAt   time.Time
	CompletedAt *time.Time
}
