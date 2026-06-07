package model

import "time"

// AppealStatus tracks manual review of a user appeal.
type AppealStatus string

const (
	AppealStatusPending  AppealStatus = "pending"
	AppealStatusApproved AppealStatus = "approved"
	AppealStatusRejected AppealStatus = "rejected"
)

// Appeal is a user appeal against a rejected audit job.
type Appeal struct {
	ID         string
	AuditJobID string
	UserID     string
	Reason     string
	Status     AppealStatus
	CreatedAt  time.Time
	ResolvedAt *time.Time
}
