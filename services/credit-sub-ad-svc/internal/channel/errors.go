package channel

import "errors"

var (
	// ErrInvalidRequest is returned when required grant fields are missing.
	ErrInvalidRequest = errors.New("invalid channel grant request")
)
