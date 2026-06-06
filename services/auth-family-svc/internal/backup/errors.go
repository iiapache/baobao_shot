package backup

import "errors"

var (
	// ErrInvalidKind is returned when provider kind is not supported.
	ErrInvalidKind = errors.New("invalid backup provider kind")
	// ErrTokenRequired is returned when OAuth token is missing for token-backed providers.
	ErrTokenRequired = errors.New("access token required")
	// ErrNotFound is returned when a provider binding does not exist for the user.
	ErrNotFound = errors.New("backup provider not found")
)
