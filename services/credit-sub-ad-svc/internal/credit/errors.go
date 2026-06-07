package credit

import "errors"

var (
	// ErrInsufficientBalance is returned when a debit would drive balance negative.
	ErrInsufficientBalance = errors.New("insufficient credit balance")
	// ErrInvalidAmount is returned when amount violates type rules.
	ErrInvalidAmount = errors.New("invalid credit amount")
	// ErrInvalidRequest is returned when required fields are missing.
	ErrInvalidRequest = errors.New("invalid credit request")
	// ErrHoldNotFound is returned when a hold id does not exist.
	ErrHoldNotFound = errors.New("credit hold not found")
	// ErrHoldSettled is returned when a hold is already committed or released.
	ErrHoldSettled = errors.New("credit hold already settled")
)
