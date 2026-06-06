package consent

import "errors"

var (
	// ErrNotAccepted indicates the client did not accept the consent document.
	ErrNotAccepted = errors.New("consent not accepted")
	// ErrVersionMismatch indicates the submitted version does not match the current one.
	ErrVersionMismatch = errors.New("consent version mismatch")
)
