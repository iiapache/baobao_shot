package family

import (
	"errors"
	"time"
)

// Limits align with docs/product-config.yaml (OPT-05).
const (
	MaxFamiliesCreated = 2
	MaxFamiliesJoined  = 3
	MaxFamilyMembers   = 8
	InviteCodeLength   = 6
	InviteTTL          = 24 * time.Hour
	InviteMaxUses      = 8

	AdminInactiveDays     = 30
	TakeoverObjectionDays = 7
	TakeoverApprovalRatio = 0.5
)

var (
	ErrCreateLimit     = errors.New("family create limit reached")
	ErrJoinLimit       = errors.New("family join limit reached")
	ErrMemberLimit     = errors.New("family member limit reached")
	ErrNotFound        = errors.New("family not found")
	ErrNotMember       = errors.New("not a family member")
	ErrNotAdmin        = errors.New("not family admin")
	ErrInvalidName     = errors.New("invalid family name")
	ErrInvalidRegion   = errors.New("invalid region")
	ErrInviteNotFound  = errors.New("invite not found")
	ErrInviteExpired   = errors.New("invite expired")
	ErrInviteUsedUp    = errors.New("invite used up")
	ErrInviteRevoked   = errors.New("invite revoked")
	ErrAlreadyMember   = errors.New("already a family member")
	ErrInvalidRelation       = errors.New("invalid relation")
	ErrTransferTargetInvalid = errors.New("invalid transfer target")
	ErrTransferSelf          = errors.New("cannot transfer to self")
	ErrAdminActive           = errors.New("admin is still active")
	ErrTakeoverNotEligible   = errors.New("not eligible for takeover")
	ErrTakeoverAlreadyVoted  = errors.New("already voted on takeover")
	ErrTakeoverNoActiveVote  = errors.New("no active takeover vote")
	ErrInvalidChoice         = errors.New("invalid ballot choice")
	ErrTakeoverInProgress    = errors.New("takeover already in progress")
)
