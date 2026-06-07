package seedance

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
		{"50411", http.StatusOK, adapter.ErrCodeRateLimited, true},
		{"50500", http.StatusInternalServerError, adapter.ErrCodeUpstream, true},
		{"50501", http.StatusOK, adapter.ErrCodeTransient, true},
		{"60208", http.StatusOK, adapter.ErrCodeFaceNotFound, false},
		{"40301", http.StatusOK, adapter.ErrCodeContentPolicy, false},
		{"40001", http.StatusBadRequest, adapter.ErrCodeInvalidInput, false},
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
				t.Fatalf("IsRetryable = %v, want %v", adapter.IsRetryable(err), tc.retryable)
			}
		})
	}
}
