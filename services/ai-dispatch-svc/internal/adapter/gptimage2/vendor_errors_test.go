package gptimage2

import (
	"net/http"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
)

func TestNormalizeVendorError(t *testing.T) {
	cases := []struct {
		code       string
		httpStatus int
		wantCode   adapter.ErrorCode
		retryable  bool
	}{
		{"rate_limit_exceeded", http.StatusTooManyRequests, adapter.ErrCodeRateLimited, true},
		{"server_error", http.StatusInternalServerError, adapter.ErrCodeUpstream, true},
		{"timeout", http.StatusOK, adapter.ErrCodeTransient, true},
		{"face_not_detected", http.StatusOK, adapter.ErrCodeFaceNotFound, false},
		{"content_policy_violation", http.StatusOK, adapter.ErrCodeContentPolicy, false},
		{"invalid_request_error", http.StatusBadRequest, adapter.ErrCodeInvalidInput, false},
	}

	for _, tc := range cases {
		err := NormalizeVendorError(tc.code, tc.httpStatus, "msg")
		if err.Code != tc.wantCode {
			t.Fatalf("code %s -> %s, want %s", tc.code, err.Code, tc.wantCode)
		}
		if adapter.IsRetryable(err) != tc.retryable {
			t.Fatalf("retryable for %s = %v, want %v", tc.code, adapter.IsRetryable(err), tc.retryable)
		}
	}
}

func TestNormalizeHTTPStatus_Transient(t *testing.T) {
	err := NormalizeHTTPStatus(http.StatusGatewayTimeout, "timeout")
	if err.Code != adapter.ErrCodeTransient {
		t.Fatalf("code = %s, want %s", err.Code, adapter.ErrCodeTransient)
	}
	if !adapter.IsRetryable(err) {
		t.Fatal("gateway timeout should be retryable")
	}
}
