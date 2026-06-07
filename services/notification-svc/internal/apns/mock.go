package apns

import (
	"context"
	"fmt"
	"strings"
	"sync/atomic"

	"github.com/google/uuid"
)

const invalidTokenPrefix = "invalid:"

// MockSender simulates APNs HTTP/2 without contacting Apple.
// Tokens prefixed with "invalid:" return ErrTokenInvalid.
type MockSender struct {
	sends atomic.Int64
}

// NewMockSender returns a stub sender for dev and tests.
func NewMockSender() *MockSender {
	return &MockSender{}
}

// SendCount returns how many pushes were attempted.
func (m *MockSender) SendCount() int64 {
	if m == nil {
		return 0
	}
	return m.sends.Load()
}

// Send implements Sender.
func (m *MockSender) Send(_ context.Context, host string, payload PushPayload) (SendResult, error) {
	if m == nil {
		return SendResult{}, fmt.Errorf("mock sender is nil")
	}
	m.sends.Add(1)

	token := strings.TrimSpace(payload.DeviceToken)
	if token == "" {
		return SendResult{StatusCode: 400, TokenInvalid: true}, ErrTokenInvalid
	}
	if strings.HasPrefix(token, invalidTokenPrefix) {
		return SendResult{
			APNSID:       "",
			StatusCode:   410,
			TokenInvalid: true,
		}, ErrTokenInvalid
	}

	return SendResult{
		APNSID:     "apns_" + uuid.NewString()[:12],
		StatusCode: 200,
	}, nil
}

// IsInvalidTestToken reports whether a token should simulate APNs rejection.
func IsInvalidTestToken(token string) bool {
	return strings.HasPrefix(strings.TrimSpace(token), invalidTokenPrefix)
}
