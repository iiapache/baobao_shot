package tongyi

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

// vendorRetryCodes are DashScope transient error codes.
var vendorRetryCodes = map[string]adapter.ErrorCode{
	"Throttling":        adapter.ErrCodeRateLimited,
	"Throttling.RateQuota": adapter.ErrCodeRateLimited,
	"RequestTimeout":    adapter.ErrCodeTransient,
	"InternalError":     adapter.ErrCodeUpstream,
	"ServiceUnavailable": adapter.ErrCodeUpstream,
	"SystemError":       adapter.ErrCodeUpstream,
}

// vendorRejectCodes are business-level failures that must not retry.
var vendorRejectCodes = map[string]adapter.ErrorCode{
	"InvalidParameter":      adapter.ErrCodeInvalidInput,
	"InvalidApiKey":           adapter.ErrCodeAuth,
	"AccessDenied":            adapter.ErrCodeAuth,
	"DataInspectionFailed":    adapter.ErrCodeContentPolicy,
	"IPInfringementSuspect":   adapter.ErrCodeContentPolicy,
	"InvalidImage":            adapter.ErrCodeInvalidInput,
	"InvalidImageFormat":      adapter.ErrCodeInvalidInput,
	"InvalidImageResolution":  adapter.ErrCodeInvalidInput,
	"FaceNotDetected":         adapter.ErrCodeFaceNotFound,
}

// NormalizeVendorError maps DashScope code / HTTP status to internal AdapterError.
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
