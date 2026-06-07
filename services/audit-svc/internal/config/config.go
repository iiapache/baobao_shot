package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	DefaultHTTPPort = 8005
	DefaultGRPCPort = 9005
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName    string
	HTTPPort       int
	GRPCPort       int
	OTelEndpoint   string
	Environment    string
	DeployRegion   string
	StorageBackend string
	DatabaseURL    string
	KafkaBrokers   string
	KafkaTopic     string
	KafkaGroupID   string

	AliyunGreenMockMode        bool
	AliyunGreenAccessKeyID     string
	AliyunGreenAccessKeySecret string
	AliyunGreenRegion          string
	AliyunGreenImageScenes     string
	AliyunGreenTextScenes      string
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

	aliyunAccessKeyID := getEnv("ALIYUN_GREEN_ACCESS_KEY_ID", "")
	aliyunMockMode, err := getEnvBool("ALIYUN_GREEN_MOCK_MODE", aliyunAccessKeyID == "")
	if err != nil {
		return nil, fmt.Errorf("ALIYUN_GREEN_MOCK_MODE: %w", err)
	}

	deployRegion := strings.ToLower(getEnv("DEPLOY_REGION", "cn"))
	if deployRegion != "cn" && deployRegion != "os" {
		return nil, fmt.Errorf("DEPLOY_REGION: unsupported region %q", deployRegion)
	}

	return &Config{
		ServiceName:    getEnv("SERVICE_NAME", "audit-svc"),
		HTTPPort:       httpPort,
		GRPCPort:       grpcPort,
		OTelEndpoint:   getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:    getEnv("ENVIRONMENT", "dev"),
		DeployRegion:   deployRegion,
		StorageBackend: backend,
		DatabaseURL:    getEnv("DATABASE_URL", ""),
		KafkaBrokers:   getEnv("KAFKA_BROKERS", ""),
		KafkaTopic:     getEnv("KAFKA_TOPIC", "feed.events"),
		KafkaGroupID:   getEnv("KAFKA_GROUP_ID", "audit-svc"),

		AliyunGreenMockMode:        aliyunMockMode,
		AliyunGreenAccessKeyID:     aliyunAccessKeyID,
		AliyunGreenAccessKeySecret: getEnv("ALIYUN_GREEN_ACCESS_KEY_SECRET", ""),
		AliyunGreenRegion:          getEnv("ALIYUN_GREEN_REGION", "cn-shanghai"),
		AliyunGreenImageScenes:     getEnv("ALIYUN_GREEN_IMAGE_SCENE", "porn,terrorism,ad,qrcode,live"),
		AliyunGreenTextScenes:      getEnv("ALIYUN_GREEN_TEXT_SCENE", "antispam"),
	}, nil
}

// KafkaEnabled reports whether a Kafka broker list is configured.
func (c *Config) KafkaEnabled() bool {
	return c != nil && strings.TrimSpace(c.KafkaBrokers) != ""
}

// AliyunGreenEnabled reports whether the CN Aliyun content security adapter is active.
func (c *Config) AliyunGreenEnabled() bool {
	if c == nil {
		return false
	}
	return c.AliyunGreenMockMode || strings.TrimSpace(c.AliyunGreenAccessKeyID) != ""
}

func getEnvBool(key string, fallback bool) (bool, error) {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback, nil
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		return false, err
	}
	return v, nil
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
