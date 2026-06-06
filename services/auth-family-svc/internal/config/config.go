package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName      string
	HTTPPort         int
	GRPCPort         int
	OTelEndpoint     string
	Environment      string
	StorageBackend   string
	DatabaseURL      string
	MockAppleVerify  bool
	AppleBundleID    string
	JWTSigningSecret    string
	RedisURL            string
	InviteSigningSecret string
	AppScheme           string
	AvatarStoragePath   string
	AvatarCDNBase       string
}

// Load reads configuration from environment with sensible defaults.
func Load() (*Config, error) {
	httpPort, err := strconv.Atoi(getEnv("HTTP_PORT", "8001"))
	if err != nil {
		return nil, fmt.Errorf("HTTP_PORT: %w", err)
	}
	grpcPort, err := strconv.Atoi(getEnv("GRPC_PORT", "9001"))
	if err != nil {
		return nil, fmt.Errorf("GRPC_PORT: %w", err)
	}

	backend := strings.ToLower(getEnv("STORAGE_BACKEND", "memory"))
	if backend != "memory" && backend != "postgres" {
		return nil, fmt.Errorf("STORAGE_BACKEND: unsupported backend %q", backend)
	}

	mockApple := strings.EqualFold(getEnv("MOCK_APPLE_VERIFY", "true"), "true")
	jwtSecret := getEnv("JWT_SIGNING_SECRET", "dev-only-change-me")

	return &Config{
		ServiceName:         getEnv("SERVICE_NAME", "auth-family-svc"),
		HTTPPort:            httpPort,
		GRPCPort:            grpcPort,
		OTelEndpoint:        getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:         getEnv("ENVIRONMENT", "dev"),
		StorageBackend:      backend,
		DatabaseURL:         getEnv("DATABASE_URL", ""),
		MockAppleVerify:     mockApple,
		AppleBundleID:       getEnv("APPLE_BUNDLE_ID", ""),
		JWTSigningSecret:    jwtSecret,
		RedisURL:            getEnv("REDIS_URL", ""),
		InviteSigningSecret: getEnv("INVITE_SIGNING_SECRET", jwtSecret),
		AppScheme:           getEnv("APP_SCHEME", "baobao://invite"),
		AvatarStoragePath:   getEnv("AVATAR_STORAGE_PATH", "./data/avatar"),
		AvatarCDNBase:       getEnv("AVATAR_CDN_BASE", ""),
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
