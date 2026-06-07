package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	DefaultHTTPPort = 8008
	DefaultGRPCPort = 9008
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName    string
	HTTPPort       int
	GRPCPort       int
	OTelEndpoint   string
	Environment    string
	StorageBackend string
	DatabaseURL    string
	APNSSandbox    bool
	APNSTopic      string
	DebugEndpoints bool
	KafkaBrokers   string
	KafkaGroupID   string
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

	sandbox := strings.EqualFold(getEnv("APNS_SANDBOX", "true"), "true")
	debug := strings.EqualFold(getEnv("DEBUG_ENDPOINTS", "true"), "true")
	if getEnv("ENVIRONMENT", "dev") == "prod" {
		debug = strings.EqualFold(getEnv("DEBUG_ENDPOINTS", "false"), "true")
	}

	return &Config{
		ServiceName:    getEnv("SERVICE_NAME", "notification-svc"),
		HTTPPort:       httpPort,
		GRPCPort:       grpcPort,
		OTelEndpoint:   getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:    getEnv("ENVIRONMENT", "dev"),
		StorageBackend: backend,
		DatabaseURL:    getEnv("DATABASE_URL", ""),
		APNSSandbox:    sandbox,
		APNSTopic:      getEnv("APNS_TOPIC", "app.babycamera"),
		DebugEndpoints: debug,
		KafkaBrokers:   getEnv("KAFKA_BROKERS", ""),
		KafkaGroupID:   getEnv("KAFKA_GROUP_ID", "notification-svc"),
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
