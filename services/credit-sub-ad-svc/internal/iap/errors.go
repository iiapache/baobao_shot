package iap

import "errors"

var (
	// ErrVerifyFailed is returned when JWS verification fails.
	ErrVerifyFailed = errors.New("iap verify failed")
	// ErrProductUnknown is returned when productId is not in the catalog.
	ErrProductUnknown = errors.New("iap product unknown")
	// ErrProductMismatch is returned when request productId conflicts with stored receipt.
	ErrProductMismatch = errors.New("iap product mismatch")
	// ErrUserMismatch is returned when transactionId belongs to another user.
	ErrUserMismatch = errors.New("iap user mismatch")
	// ErrTransactionMismatch is returned when request transactionId differs from JWS payload.
	ErrTransactionMismatch = errors.New("iap transaction mismatch")
	// ErrInvalidRequest is returned when required fields are missing.
	ErrInvalidRequest = errors.New("invalid iap request")
)
