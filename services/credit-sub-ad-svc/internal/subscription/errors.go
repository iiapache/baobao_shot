package subscription

import "errors"

var (
	ErrInvalidRequest      = errors.New("subscription: invalid request")
	ErrVerifyFailed        = errors.New("subscription: iap verification failed")
	ErrProductMismatch     = errors.New("subscription: productId mismatch")
	ErrProductUnknown      = errors.New("subscription: unknown productId")
	ErrUserMismatch        = errors.New("subscription: transaction bound to another user")
	ErrTransactionMismatch = errors.New("subscription: transactionId mismatch")
	ErrInvalidTransition   = errors.New("subscription: invalid state transition")
)
