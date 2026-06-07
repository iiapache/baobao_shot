package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	DefaultHTTPPort = 8004
	DefaultGRPCPort = 9004
)

// Config holds service runtime configuration from environment variables.
type Config struct {
	ServiceName        string
	HTTPPort           int
	GRPCPort           int
	OTelEndpoint       string
	Environment        string
	StoreBackend       string
	MongoURI           string
	MongoDatabase      string
	KafkaBrokers       []string
	KafkaEnabled       bool
	WorkerEnabled      bool
	WorkerPoolSize     int
	JWTSigningSecret   string
	ConfigSvcURL          string
	AlgorithmFilingPath   string
	AuditSvcURL        string
	CreditSvcGRPCAddr       string
	CostMeteringCronEnabled bool
	WSPingIntervalSecs      int
	WSPongTimeoutSecs  int
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

	backend := strings.ToLower(getEnv("STORE_BACKEND", "memory"))
	if backend != "memory" && backend != "mongo" {
		return nil, fmt.Errorf("STORE_BACKEND: unsupported backend %q", backend)
	}

	kafkaEnabled := strings.ToLower(getEnv("KAFKA_ENABLED", "false")) == "true"
	brokers := splitCSV(getEnv("KAFKA_BROKERS", "localhost:9092"))

	wsPing, err := strconv.Atoi(getEnv("WS_PING_INTERVAL_SECS", "30"))
	if err != nil {
		return nil, fmt.Errorf("WS_PING_INTERVAL_SECS: %w", err)
	}
	wsPong, err := strconv.Atoi(getEnv("WS_PONG_TIMEOUT_SECS", "60"))
	if err != nil {
		return nil, fmt.Errorf("WS_PONG_TIMEOUT_SECS: %w", err)
	}
	workerEnabled := strings.ToLower(getEnv("WORKER_ENABLED", "true")) == "true"
	workerPoolSize, err := strconv.Atoi(getEnv("WORKER_POOL_SIZE", "4"))
	if err != nil {
		return nil, fmt.Errorf("WORKER_POOL_SIZE: %w", err)
	}
	if workerPoolSize < 1 {
		return nil, fmt.Errorf("WORKER_POOL_SIZE: must be >= 1")
	}

	return &Config{
		ServiceName:        getEnv("SERVICE_NAME", "ai-dispatch-svc"),
		HTTPPort:           httpPort,
		GRPCPort:           grpcPort,
		OTelEndpoint:       getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:        getEnv("ENVIRONMENT", "dev"),
		StoreBackend:       backend,
		MongoURI:           getEnv("MONGO_URI", "mongodb://localhost:27017"),
		MongoDatabase:      getEnv("MONGO_DATABASE", "baobao"),
		KafkaBrokers:       brokers,
		KafkaEnabled:       kafkaEnabled,
		WorkerEnabled:      workerEnabled,
		WorkerPoolSize:     workerPoolSize,
		JWTSigningSecret:   getEnv("JWT_SIGNING_SECRET", "dev-only-change-me"),
		ConfigSvcURL:        getEnv("CONFIG_SVC_URL", ""),
		AlgorithmFilingPath: getEnv("ALGORITHM_FILING_PATH", ""),
		AuditSvcURL:        getEnv("AUDIT_SVC_URL", ""),
		CreditSvcGRPCAddr:       getEnv("CREDIT_SVC_GRPC_ADDR", ""),
		CostMeteringCronEnabled: strings.ToLower(getEnv("COST_METERING_CRON_ENABLED", "false")) == "true",
		WSPingIntervalSecs:      wsPing,
		WSPongTimeoutSecs:  wsPong,
	}, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func splitCSV(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// HTTPAddr returns the HTTP listen address.
func (c *Config) HTTPAddr() string {
	return fmt.Sprintf(":%d", c.HTTPPort)
}

// GRPCAddr returns the gRPC listen address.
func (c *Config) GRPCAddr() string {
	return fmt.Sprintf(":%d", c.GRPCPort)
}
