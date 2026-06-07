package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	DefaultHTTPPort = 8002
	DefaultGRPCPort = 9002
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
	RedisURL       string

	OSSCleanupWorkerEnabled  bool
	OSSCleanupWorkerInterval time.Duration
	OSSReconcileCronEnabled  bool
	OSSReconcileCronInterval time.Duration
	OSSReconcileStaleAfter   time.Duration

	AuditSvcURL string
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

	ossWorkerMinutes, err := strconv.Atoi(getEnv("OSS_CLEANUP_WORKER_INTERVAL_MINUTES", "1"))
	if err != nil {
		return nil, fmt.Errorf("OSS_CLEANUP_WORKER_INTERVAL_MINUTES: %w", err)
	}
	reconcileMinutes, err := strconv.Atoi(getEnv("OSS_RECONCILE_CRON_INTERVAL_MINUTES", "15"))
	if err != nil {
		return nil, fmt.Errorf("OSS_RECONCILE_CRON_INTERVAL_MINUTES: %w", err)
	}
	reconcileStaleHours, err := strconv.Atoi(getEnv("OSS_RECONCILE_STALE_AFTER_HOURS", "24"))
	if err != nil {
		return nil, fmt.Errorf("OSS_RECONCILE_STALE_AFTER_HOURS: %w", err)
	}

	return &Config{
		ServiceName:    getEnv("SERVICE_NAME", "feed-svc"),
		HTTPPort:       httpPort,
		GRPCPort:       grpcPort,
		OTelEndpoint:   getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:    getEnv("ENVIRONMENT", "dev"),
		StorageBackend: backend,
		DatabaseURL:    getEnv("DATABASE_URL", ""),
		RedisURL:       getEnv("REDIS_URL", ""),

		OSSCleanupWorkerEnabled:  strings.ToLower(getEnv("OSS_CLEANUP_WORKER_ENABLED", "true")) == "true",
		OSSCleanupWorkerInterval: time.Duration(ossWorkerMinutes) * time.Minute,
		OSSReconcileCronEnabled:  strings.ToLower(getEnv("OSS_RECONCILE_CRON_ENABLED", "true")) == "true",
		OSSReconcileCronInterval: time.Duration(reconcileMinutes) * time.Minute,
		OSSReconcileStaleAfter:   time.Duration(reconcileStaleHours) * time.Hour,
		AuditSvcURL:              getEnv("AUDIT_SVC_URL", ""),
	}, nil
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
