package model

import "time"

// InviteCode is a family invitation record.
type InviteCode struct {
	Code      string
	FamilyID  string
	CreatedBy string
	ExpireAt  time.Time
	MaxUses   int
	UsedCount int
	RevokedAt *time.Time
	CreatedAt time.Time
}
