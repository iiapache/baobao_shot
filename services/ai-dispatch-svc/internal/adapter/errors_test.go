package adapter

import "testing"

func TestIsRetryable_Whitelist(t *testing.T) {
	cases := []struct {
		code      ErrorCode
		retryable bool
	}{
		{ErrCodeTransient, true},
		{ErrCodeRateLimited, true},
		{ErrCodeUpstream, true},
		{ErrCodeInvalidInput, false},
		{ErrCodeFaceNotFound, false},
		{ErrCodeContentPolicy, false},
		{ErrCodeAuth, false},
	}

	for _, tc := range cases {
		t.Run(string(tc.code), func(t *testing.T) {
			err := NewAdapterError(tc.code, "V", "msg")
			if IsRetryable(err) != tc.retryable {
				t.Fatalf("IsRetryable(%s) = %v, want %v", tc.code, IsRetryable(err), tc.retryable)
			}
			if err.Retryable != tc.retryable {
				t.Fatalf("Retryable field = %v, want %v", err.Retryable, tc.retryable)
			}
		})
	}
}
