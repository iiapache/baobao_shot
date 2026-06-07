package adreward

import "errors"

var (
	// ErrInvalidRequest is returned when required fields are missing.
	ErrInvalidRequest = errors.New("invalid ad reward request")
	// ErrInvalidSignature is returned when alliance callback signature fails verification.
	ErrInvalidSignature = errors.New("invalid ad reward signature")
	// ErrDailyLimit is returned when the user exceeded the daily reward cap.
	ErrDailyLimit = errors.New("ad reward daily limit exceeded")
	// ErrFrequencyLimit is returned when rewards are requested too frequently.
	ErrFrequencyLimit = errors.New("ad reward frequency limit exceeded")
	// ErrIDFVMismatch is returned when IDFV does not match the registered device.
	ErrIDFVMismatch = errors.New("ad reward idfv mismatch")
	// ErrReplay is returned when nonce/timestamp anti-replay check fails.
	ErrReplay = errors.New("ad reward replay detected")
)
