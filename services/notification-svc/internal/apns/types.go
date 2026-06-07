package apns

import (
	"context"
	"errors"
)

// Region identifies the deployment region for APNs routing.
type Region string

const (
	RegionCN Region = "cn"
	RegionOS Region = "os"
)

const (
	HostProduction = "api.push.apple.com:443"
	HostSandbox    = "api.sandbox.push.apple.com:443"
)

var (
	ErrUnsupportedRegion = errors.New("unsupported apns region")
	ErrTokenInvalid      = errors.New("apns token invalid")
)

// PushPayload is the minimal alert payload for APNs HTTP/2.
type PushPayload struct {
	DeviceToken string
	Title       string
	Body        string
	Priority    int
	Silent      bool
	Topic       string
	Category    string
	CustomData  map[string]string
}

// SendResult summarizes an APNs send attempt.
type SendResult struct {
	APNSID       string
	StatusCode   int
	TokenInvalid bool
}

// Sender performs the HTTP/2 APNs request. Production wiring replaces MockSender.
type Sender interface {
	Send(ctx context.Context, host string, payload PushPayload) (SendResult, error)
}

// TokenCleaner removes invalid device tokens from persistence.
type TokenCleaner interface {
	CleanupInvalidToken(ctx context.Context, apnsToken string) (int64, error)
}
