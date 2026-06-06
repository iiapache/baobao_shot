package model

import "time"

// UserStatus represents account lifecycle state.
type UserStatus string

const (
	UserStatusActive    UserStatus = "active"
	UserStatusSuspended UserStatus = "suspended"
	UserStatusDeleted   UserStatus = "deleted"
)

// User is the persisted account record for auth-family-svc.
type User struct {
	ID                   string
	AppleSub             *string
	Phone                *string
	Region               string
	Nickname             string
	AvatarURL            *string
	Status               UserStatus
	ChildDataConsentAt   *time.Time
	CreatedAt            time.Time
	UpdatedAt            time.Time
	LastSeenAt           time.Time
	DeletedAt            *time.Time
}

// HasChildDataConsent reports whether the user granted child-data consent.
func (u *User) HasChildDataConsent() bool {
	return u.ChildDataConsentAt != nil
}
