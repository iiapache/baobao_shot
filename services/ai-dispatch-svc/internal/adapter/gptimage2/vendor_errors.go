package gptimage2

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

// vendorRetryCodes are OpenAI transient error codes.
var vendorRetryCodes = map[string]adapter.ErrorCode{
	"rate_limit_exceeded": adapter.ErrCodeRateLimited,
	"server_error":        adapter.ErrCodeUpstream,
	"timeout":               adapter.ErrCodeTransient,
	"overloaded":            adapter.ErrCodeUpstream,
	"503":                   adapter.ErrCodeUpstream,
	"504":                   adapter.ErrCodeTransient,
}

// vendorRejectCodes are business-level failures that must not retry.
var vendorRejectCodes = map[string]adapter.ErrorCode{
	"invalid_request_error":   adapter.ErrCodeInvalidInput,
	"authentication_error":    adapter.ErrCodeAuth,
	"permission_denied_error": adapter.ErrCodeAuth,
	"content_policy_violation": adapter.ErrCodeContentPolicy,
	"safety_system":           adapter.ErrCodeContentPolicy,
	"face_not_detected":       adapter.ErrCodeFaceNotFound,
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
	case httpStatus == 0:
		return adapter.NewAdapterError(adapter.ErrCodeTransient, code, message)
	case httpStatus == http.StatusRequestTimeout || httpStatus == http.StatusGatewayTimeout:
		return adapter.NewAdapterError(adapter.ErrCodeTransient, code, message)
	case httpStatus == http.StatusTooManyRequests:
		return adapter.NewAdapterError(adapter.ErrCodeRateLimited, code, message)
	case httpStatus >= 500:
		return adapter.NewAdapterError(adapter.ErrCodeUpstream, code, message)
	default:
		return adapter.NewAdapterError(adapter.ErrCodeInvalidInput, code, message)
	}
}

// NormalizeHTTPStatus maps transport-level failures without vendor body.
func NormalizeHTTPStatus(status int, message string) *adapter.AdapterError {
	return NormalizeVendorError(strconv.Itoa(status), status, message)
}
