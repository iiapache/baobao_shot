package signin

import "errors"

var (
	// ErrInvalidRequest is returned when required sign-in fields are missing.
	ErrInvalidRequest = errors.New("invalid sign-in request")
	// ErrSignInDone is returned when the user already signed in today.
	ErrSignInDone = errors.New("sign-in already done today")
)
