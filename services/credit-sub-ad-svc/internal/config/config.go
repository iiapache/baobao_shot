package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	DefaultHTTPPort = 8006
	DefaultGRPCPort = 9006
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName        string
	HTTPPort           int
	GRPCPort           int
	OTelEndpoint       string
	Environment        string
	StorageBackend     string
	DatabaseURL        string
	AppleIAPBundleID          string
	RedisURL                  string
	KafkaBrokers              string
	KafkaTopic                string
	KafkaGroupID              string
	SubscriptionCronEnabled   bool
	SubscriptionCronInterval  time.Duration
	PangleSecurityKey         string
	GDTSecretKey              string
	AdRewardDailyLimit        int
	AdRewardMinIntervalSec    int
	ReconciliationCronEnabled bool
	ReconciliationCronInterval time.Duration
	AIDispatchCostMeteringURL string
}

// Load reads configuration from environment with sensible defaults.
func Load() (*Config, error) {
	httpPort, err := strconv.Atoi(getEnv("HTTP_PORT", strconv.Itoa(DefaultHTTPPort)))
	if err != nil {
		return nil, fmt.Errorf("HTTP_PORT: %w", err)
	}
	grpcPort, err := strconv.Atoi(getEnv("GRPC_PORT", strconv.Itoa(DefaultGRPCPort)))
	if err != nil {
		return nil, fmt.Errorf("GRPC_PORT: %w", err)
	}

	backend := strings.ToLower(getEnv("STORAGE_BACKEND", "memory"))
	if backend != "memory" && backend != "postgres" {
		return nil, fmt.Errorf("STORAGE_BACKEND: unsupported backend %q", backend)
	}

	cronIntervalHours, err := strconv.Atoi(getEnv("SUBSCRIPTION_CRON_INTERVAL_HOURS", "24"))
	if err != nil {
		return nil, fmt.Errorf("SUBSCRIPTION_CRON_INTERVAL_HOURS: %w", err)
	}
	if cronIntervalHours <= 0 {
		cronIntervalHours = 24
	}

	adDailyLimit, err := strconv.Atoi(getEnv("AD_REWARD_DAILY_LIMIT", "5"))
	if err != nil {
		return nil, fmt.Errorf("AD_REWARD_DAILY_LIMIT: %w", err)
	}
	if adDailyLimit <= 0 {
		adDailyLimit = 5
	}
	adMinIntervalSec, err := strconv.Atoi(getEnv("AD_REWARD_MIN_INTERVAL_SEC", "30"))
	if err != nil {
		return nil, fmt.Errorf("AD_REWARD_MIN_INTERVAL_SEC: %w", err)
	}
	if adMinIntervalSec <= 0 {
		adMinIntervalSec = 30
	}
	reconIntervalHours, err := strconv.Atoi(getEnv("RECONCILIATION_CRON_INTERVAL_HOURS", "24"))
	if err != nil {
		return nil, fmt.Errorf("RECONCILIATION_CRON_INTERVAL_HOURS: %w", err)
	}
	if reconIntervalHours <= 0 {
		reconIntervalHours = 24
	}

	return &Config{
		ServiceName:              getEnv("SERVICE_NAME", "credit-sub-ad-svc"),
		HTTPPort:                 httpPort,
		GRPCPort:                 grpcPort,
		OTelEndpoint:             getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:              getEnv("ENVIRONMENT", "dev"),
		StorageBackend:           backend,
		DatabaseURL:              getEnv("DATABASE_URL", ""),
		AppleIAPBundleID:         getEnv("APPLE_IAP_BUNDLE_ID", ""),
		RedisURL:                 getEnv("REDIS_URL", ""),
		KafkaBrokers:             getEnv("KAFKA_BROKERS", ""),
		KafkaTopic:               getEnv("KAFKA_TOPIC", "iap.events"),
		KafkaGroupID:             getEnv("KAFKA_GROUP_ID", "credit-sub-ad-svc"),
		SubscriptionCronEnabled:  strings.ToLower(getEnv("SUBSCRIPTION_CRON_ENABLED", "true")) == "true",
		SubscriptionCronInterval: time.Duration(cronIntervalHours) * time.Hour,
		PangleSecurityKey:        getEnv("PANGLE_SECURITY_KEY", ""),
		GDTSecretKey:             getEnv("GDT_SECRET_KEY", ""),
		AdRewardDailyLimit:         adDailyLimit,
		AdRewardMinIntervalSec:     adMinIntervalSec,
		ReconciliationCronEnabled:  strings.ToLower(getEnv("RECONCILIATION_CRON_ENABLED", "true")) == "true",
		ReconciliationCronInterval: time.Duration(reconIntervalHours) * time.Hour,
		AIDispatchCostMeteringURL:  getEnv("AI_DISPATCH_COST_METERING_URL", ""),
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

// GRPCAddr returns the gRPC listen address.
func (c *Config) GRPCAddr() string {
	return fmt.Sprintf(":%d", c.GRPCPort)
}
