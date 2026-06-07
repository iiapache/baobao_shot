package tongyi

import (
	"net/http"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

func TestNormalizeVendorError_RetryWhitelist(t *testing.T) {
	cases := []struct {
		vendorCode string
		httpStatus int
		wantCode   adapter.ErrorCode
		retryable  bool
	}{
		{"Throttling", http.StatusOK, adapter.ErrCodeRateLimited, true},
		{"InternalError", http.StatusInternalServerError, adapter.ErrCodeUpstream, true},
		{"RequestTimeout", http.StatusOK, adapter.ErrCodeTransient, true},
		{"FaceNotDetected", http.StatusOK, adapter.ErrCodeFaceNotFound, false},
		{"DataInspectionFailed", http.StatusOK, adapter.ErrCodeContentPolicy, false},
		{"InvalidParameter", http.StatusBadRequest, adapter.ErrCodeInvalidInput, false},
	}

	for _, tc := range cases {
		t.Run(tc.vendorCode, func(t *testing.T) {
			err := NormalizeVendorError(tc.vendorCode, tc.httpStatus, "msg")
			if err.Code != tc.wantCode {
				t.Fatalf("code = %s, want %s", err.Code, tc.wantCode)
			}
			if err.Retryable != tc.retryable {
				t.Fatalf("retryable = %v, want %v", err.Retryable, tc.retryable)
			}
			if adapter.IsRetryable(err) != tc.retryable {
				t.Fatal("IsRetryable mismatch")
			}
		})
	}
}

func TestNormalizeHTTPStatus_Transient(t *testing.T) {
	err := NormalizeHTTPStatus(http.StatusGatewayTimeout, "timeout")
	if err.Code != adapter.ErrCodeTransient {
		t.Fatalf("code = %s, want %s", err.Code, adapter.ErrCodeTransient)
	}
	if !adapter.IsRetryable(err) {
		t.Fatal("expected retryable")
	}
}
