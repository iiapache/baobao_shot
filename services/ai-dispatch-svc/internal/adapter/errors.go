package adapter

import (
	"errors"
	"fmt"
)

// ErrorCode is the normalized model-vendor failure code (worker / API layer).
type ErrorCode string

const (
	ErrCodeTransient      ErrorCode = "MODEL_TRANSIENT"
	ErrCodeRateLimited    ErrorCode = "MODEL_RATE_LIMITED"
	ErrCodeUpstream       ErrorCode = "MODEL_UPSTREAM"
	ErrCodeInvalidInput   ErrorCode = "MODEL_INVALID_INPUT"
	ErrCodeFaceNotFound   ErrorCode = "MODEL_FACE_NOT_FOUND"
	ErrCodeContentPolicy  ErrorCode = "MODEL_CONTENT_POLICY"
	ErrCodeUnsupported    ErrorCode = "MODEL_UNSUPPORTED"
	ErrCodeAuth           ErrorCode = "MODEL_AUTH"
)

// retryWhitelist defines vendor-normalized codes eligible for automatic retry (design-backend §5.5).
var retryWhitelist = map[ErrorCode]bool{
	ErrCodeTransient:   true,
	ErrCodeRateLimited: true,
	ErrCodeUpstream:    true,
}

// AdapterError carries normalized semantics for worker retry / reject decisions.
type AdapterError struct {
	Code       ErrorCode
	Retryable  bool
	VendorCode string
	Message    string
}

func (e *AdapterError) Error() string {
	if e == nil {
		return "<nil>"
	}
	if e.VendorCode != "" {
		return fmt.Sprintf("%s: %s (vendor=%s)", e.Code, e.Message, e.VendorCode)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// NewAdapterError builds an error and applies the retry whitelist.
func NewAdapterError(code ErrorCode, vendorCode, message string) *AdapterError {
	return &AdapterError{
		Code:       code,
		Retryable:  retryWhitelist[code],
		VendorCode: vendorCode,
		Message:    message,
	}
}

// AsAdapterError unwraps a normalized adapter error.
func AsAdapterError(err error) (*AdapterError, bool) {
	var ae *AdapterError
	if errors.As(err, &ae) {
		return ae, true
	}
	return nil, false
}

// IsRetryable reports whether the worker may retry the vendor call.
func IsRetryable(err error) bool {
	if ae, ok := AsAdapterError(err); ok {
		return ae.Retryable
	}
	return false
}
