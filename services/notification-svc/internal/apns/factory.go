package apns

import (
	"fmt"
	"log/slog"
	"strings"
	"time"
)

// SenderConfig selects mock vs live APNs delivery.
type SenderConfig struct {
	Mock           bool
	KeyID          string
	TeamID         string
	PrivateKeyPEM  string
	DefaultTopic   string
	RequestTimeout time.Duration
}

// NewSender returns MockSender or HTTP2Sender based on cfg.Mock.
func NewSender(cfg SenderConfig) (Sender, error) {
	if cfg.Mock {
		slog.Info("apns sender mode", "mode", "mock")
		return NewMockSender(), nil
	}

	sender, err := NewHTTP2Sender(HTTP2Config{
		KeyID:          cfg.KeyID,
		TeamID:         cfg.TeamID,
		PrivateKeyPEM:  cfg.PrivateKeyPEM,
		DefaultTopic:   cfg.DefaultTopic,
		RequestTimeout: cfg.RequestTimeout,
	})
	if err != nil {
		return nil, err
	}
	slog.Info("apns sender mode", "mode", "http2", "topic", strings.TrimSpace(cfg.DefaultTopic))
	return sender, nil
}

// ValidateSenderConfig ensures live mode has required credentials.
func ValidateSenderConfig(cfg SenderConfig) error {
	if cfg.Mock {
		return nil
	}
	if strings.TrimSpace(cfg.KeyID) == "" {
		return fmt.Errorf("APNS_KEY_ID is required when APNS_MOCK=false")
	}
	if strings.TrimSpace(cfg.TeamID) == "" {
		return fmt.Errorf("APNS_TEAM_ID is required when APNS_MOCK=false")
	}
	if strings.TrimSpace(cfg.PrivateKeyPEM) == "" {
		return fmt.Errorf("APNS_PRIVATE_KEY_PEM is required when APNS_MOCK=false")
	}
	return nil
}
