package model

import "time"

// MemberRole is the family membership role.
type MemberRole string

const (
	MemberRoleAdmin  MemberRole = "admin"
	MemberRoleFamily MemberRole = "family"
	MemberRoleGuest  MemberRole = "guest"
)

// Family is a family group record.
type Family struct {
	ID          string
	Name        string
	AdminUserID string
	Region      string
	Plan        string
	CreatedAt   time.Time
}

// Membership links a user to a family.
type Membership struct {
	UserID    string
	FamilyID  string
	Role      MemberRole
	Nickname  string
	JoinedAt  time.Time
	RemovedAt *time.Time
}

// FamilyMember is a member entry in family detail responses.
type FamilyMember struct {
	UserID   string
	Role     MemberRole
	Nickname string
	JoinedAt time.Time
}
