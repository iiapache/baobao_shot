package config

import (
	"encoding/base64"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/baobao/auth-family-svc/internal/crypto/seal"
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
	BackupTokenEncKey   string
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
		BackupTokenEncKey:   getEnv("BACKUP_TOKEN_ENC_KEY", ""),
	}, nil
}

// BackupTokenSealer returns the AES sealer for backup OAuth tokens at rest.
// When BACKUP_TOKEN_ENC_KEY is unset, derives a dev key from JWT_SIGNING_SECRET.
func (c *Config) BackupTokenSealer() (*seal.Sealer, error) {
	key, err := c.backupTokenEncKeyBytes()
	if err != nil {
		return nil, err
	}
	return seal.New(key)
}

func (c *Config) backupTokenEncKeyBytes() ([]byte, error) {
	if c.BackupTokenEncKey != "" {
		key, err := base64.StdEncoding.DecodeString(c.BackupTokenEncKey)
		if err != nil {
			return nil, fmt.Errorf("BACKUP_TOKEN_ENC_KEY: invalid base64: %w", err)
		}
		if len(key) != 32 {
			return nil, fmt.Errorf("BACKUP_TOKEN_ENC_KEY: must decode to 32 bytes, got %d", len(key))
		}
		return key, nil
	}
	return seal.DeriveKeyFromSecret(c.JWTSigningSecret), nil
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
