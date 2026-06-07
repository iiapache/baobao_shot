package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	DefaultHTTPPort       = 8003
	DefaultGRPCPort       = 9003
	DefaultSTSTTLSeconds  = 600
	DefaultOSSBucket      = "baby-camera-cn"
	DefaultOSSRegion      = "oss-cn-hangzhou"
	DefaultOSSEndpoint    = "https://oss-cn-hangzhou.aliyuncs.com"
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
	JWTSigningSecret string
	STSTTLSeconds    int
	OSSBucket        string
	OSSRegion        string
	OSSEndpoint      string
	MockOSSBaseURL   string
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
	stsTTL, err := strconv.Atoi(getEnv("STS_TTL_SECONDS", strconv.Itoa(DefaultSTSTTLSeconds)))
	if err != nil {
		return nil, fmt.Errorf("STS_TTL_SECONDS: %w", err)
	}
	if stsTTL <= 0 {
		return nil, fmt.Errorf("STS_TTL_SECONDS: must be positive")
	}

	backend := strings.ToLower(getEnv("STORAGE_BACKEND", "memory"))
	if backend != "memory" && backend != "postgres" {
		return nil, fmt.Errorf("STORAGE_BACKEND: unsupported backend %q", backend)
	}

	return &Config{
		ServiceName:      getEnv("SERVICE_NAME", "media-svc"),
		HTTPPort:         httpPort,
		GRPCPort:         grpcPort,
		OTelEndpoint:     getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:      getEnv("ENVIRONMENT", "dev"),
		StorageBackend:   backend,
		DatabaseURL:      getEnv("DATABASE_URL", ""),
		JWTSigningSecret: getEnv("JWT_SIGNING_SECRET", "dev-only-change-me"),
		STSTTLSeconds:    stsTTL,
		OSSBucket:        getEnv("OSS_BUCKET", DefaultOSSBucket),
		OSSRegion:        getEnv("OSS_REGION", DefaultOSSRegion),
		OSSEndpoint:      getEnv("OSS_ENDPOINT", DefaultOSSEndpoint),
		MockOSSBaseURL:   getEnv("MOCK_OSS_BASE_URL", ""),
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
