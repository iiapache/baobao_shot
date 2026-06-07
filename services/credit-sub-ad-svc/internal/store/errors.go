package store

import "errors"

var (
	// ErrNotFound is returned when a record does not exist.
	ErrNotFound = errors.New("not found")
	// ErrVersionConflict is returned when optimistic lock version does not match.
	ErrVersionConflict = errors.New("balance version conflict")
	// ErrDuplicateRef is returned when ref_kind+ref_id unique constraint is violated.
	ErrDuplicateRef = errors.New("duplicate ledger ref")
	// ErrDuplicateTransaction is returned when transaction_id unique constraint is violated.
	ErrDuplicateTransaction = errors.New("duplicate iap transaction")
	// ErrDuplicateHold is returned when ai_task_id unique constraint is violated.
	ErrDuplicateHold = errors.New("duplicate credit hold")
	// ErrDuplicateAdReward is returned when network+signature unique constraint is violated.
	ErrDuplicateAdReward = errors.New("duplicate ad reward")
	// ErrHoldNotHeld is returned when a hold is not in held status.
	ErrHoldNotHeld = errors.New("credit hold not held")
)
