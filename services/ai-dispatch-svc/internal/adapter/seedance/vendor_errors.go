package seedance

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

// vendorRetryCodes are Volcengine transient error codes (design-backend §5.2 retry whitelist).
var vendorRetryCodes = map[string]adapter.ErrorCode{
	"50411": adapter.ErrCodeRateLimited,
	"50412": adapter.ErrCodeRateLimited,
	"50413": adapter.ErrCodeUpstream,
	"50500": adapter.ErrCodeUpstream,
	"50501": adapter.ErrCodeTransient,
	"50502": adapter.ErrCodeTransient,
}

// vendorRejectCodes are business-level failures that must not retry.
var vendorRejectCodes = map[string]adapter.ErrorCode{
	"40001": adapter.ErrCodeInvalidInput,
	"40003": adapter.ErrCodeInvalidInput,
	"40101": adapter.ErrCodeAuth,
	"40301": adapter.ErrCodeContentPolicy,
	"60208": adapter.ErrCodeFaceNotFound,
	"60209": adapter.ErrCodeFaceNotFound,
}

// NormalizeVendorError maps vendor code / HTTP status to internal AdapterError.
func NormalizeVendorError(vendorCode string, httpStatus int, message string) *adapter.AdapterError {
	code := strings.TrimSpace(vendorCode)
	if mapped, ok := vendorRetryCodes[code]; ok {
		return adapter.NewAdapterError(mapped, code, message)
	}
	if mapped, ok := vendorRejectCodes[code]; ok {
		return adapter.NewAdapterError(mapped, code, message)
	}

	switch {
	case httpStatus == http.StatusTooManyRequests:
		return adapter.NewAdapterError(adapter.ErrCodeRateLimited, code, message)
	case httpStatus >= 500:
		return adapter.NewAdapterError(adapter.ErrCodeUpstream, code, message)
	case httpStatus == 0 || httpStatus == http.StatusRequestTimeout || httpStatus == http.StatusGatewayTimeout:
		return adapter.NewAdapterError(adapter.ErrCodeTransient, code, message)
	default:
		return adapter.NewAdapterError(adapter.ErrCodeInvalidInput, code, message)
	}
}

// NormalizeHTTPStatus maps transport-level failures without vendor body.
func NormalizeHTTPStatus(status int, message string) *adapter.AdapterError {
	return NormalizeVendorError(strconv.Itoa(status), status, message)
}
