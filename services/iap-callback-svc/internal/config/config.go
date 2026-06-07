package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const DefaultHTTPPort = 8010

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName      string
	HTTPPort         int
	OTelEndpoint     string
	Environment      string
	DeployRegion     string
	AppleIAPBundleID string
	KafkaBrokers     string
	KafkaTopic       string
}

// Load reads configuration from environment with sensible defaults.
func Load() (*Config, error) {
	httpPort, err := strconv.Atoi(getEnv("HTTP_PORT", strconv.Itoa(DefaultHTTPPort)))
	if err != nil {
		return nil, fmt.Errorf("HTTP_PORT: %w", err)
	}

	deployRegion := strings.ToLower(getEnv("DEPLOY_REGION", "cn"))
	if deployRegion != "cn" && deployRegion != "os" {
		return nil, fmt.Errorf("DEPLOY_REGION: unsupported region %q", deployRegion)
	}

	return &Config{
		ServiceName:      getEnv("SERVICE_NAME", "iap-callback-svc"),
		HTTPPort:         httpPort,
		OTelEndpoint:     getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:      getEnv("ENVIRONMENT", "dev"),
		DeployRegion:     deployRegion,
		AppleIAPBundleID: getEnv("APPLE_IAP_BUNDLE_ID", ""),
		KafkaBrokers:     getEnv("KAFKA_BROKERS", ""),
		KafkaTopic:       getEnv("KAFKA_TOPIC", "iap.events"),
	}, nil
}

// KafkaEnabled reports whether a Kafka broker list is configured.
func (c *Config) KafkaEnabled() bool {
	return c != nil && strings.TrimSpace(c.KafkaBrokers) != ""
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// HTTPAddr returns the HTTP listen address.
func (c *Config) HTTPAddr() string {
	return fmt.Sprintf(":%d", c.HTTPPort)
}
