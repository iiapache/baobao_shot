package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName  string
	HTTPPort     int
	GRPCPort     int
	OTelEndpoint string
	Environment  string
	AdminToken   string // T7.14 kill-switch; empty disables /v1/admin/*
	Storage      StorageConfig
}

// StorageConfig selects the config backing store.
type StorageConfig struct {
	// Backend is "memory" (default) or "redis".
	Backend string
	// RedisURL is used when Backend=redis (placeholder — not wired in T0.19).
	RedisURL string
}

// Load reads configuration from environment with sensible defaults.
func Load() (*Config, error) {
	httpPort, err := strconv.Atoi(getEnv("HTTP_PORT", "8009"))
	if err != nil {
		return nil, fmt.Errorf("HTTP_PORT: %w", err)
	}
	grpcPort, err := strconv.Atoi(getEnv("GRPC_PORT", "9009"))
	if err != nil {
		return nil, fmt.Errorf("GRPC_PORT: %w", err)
	}

	backend := strings.ToLower(getEnv("CONFIG_STORAGE", "memory"))
	if backend != "memory" && backend != "redis" {
		return nil, fmt.Errorf("CONFIG_STORAGE: unsupported backend %q", backend)
	}

	return &Config{
		ServiceName:  getEnv("SERVICE_NAME", "config-svc"),
		HTTPPort:     httpPort,
		GRPCPort:     grpcPort,
		OTelEndpoint: getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:  getEnv("ENVIRONMENT", "dev"),
		AdminToken:   getEnv("CONFIG_ADMIN_TOKEN", ""),
		Storage: StorageConfig{
			Backend:  backend,
			RedisURL: getEnv("REDIS_URL", ""),
		},
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
