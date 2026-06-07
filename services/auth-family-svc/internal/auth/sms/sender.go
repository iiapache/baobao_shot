package sms

import (
	"fmt"
	"strings"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/config"
)

// NewSender wires mock or Aliyun SMS delivery from runtime config.
func NewSender(cfg *config.Config, whitelist map[string]string) (auth.SMSSender, error) {
	if cfg == nil {
		return auth.MockSMSSender{}, nil
	}
	switch strings.ToLower(strings.TrimSpace(cfg.SMSProvider)) {
	case "", "mock":
		return auth.MockSMSSender{}, nil
	case "aliyun":
		return newAliyunSender(cfg, whitelist)
	default:
		return nil, fmt.Errorf("SMS_PROVIDER: unsupported provider %q", cfg.SMSProvider)
	}
}
