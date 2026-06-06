package account

import (
	"errors"
	"time"
)

const (
	// DeletionGracePeriod is the window during which a user may cancel account deletion.
	DeletionGracePeriod = 7 * 24 * time.Hour
)

var (
	// ErrDeletionNotPending is returned when no active deletion request exists.
	ErrDeletionNotPending = errors.New("deletion not pending")
	// ErrDeletionExpired is returned when the grace period has elapsed.
	ErrDeletionExpired = errors.New("deletion grace period expired")
	// ErrAlreadyHardDeleted is returned when the account was permanently deleted.
	ErrAlreadyHardDeleted = errors.New("account already hard deleted")
	// ErrUserNotFound is returned when the user record does not exist.
	ErrUserNotFound = errors.New("user not found")
)
