package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	ServiceName  string
	HTTPPort     int
	GRPCPort     int
	OTelEndpoint string
	Environment  string
}

func Load() (*Config, error) {
	httpPort, err := strconv.Atoi(getEnv("HTTP_PORT", "8080"))
	if err != nil {
		return nil, fmt.Errorf("HTTP_PORT: %w", err)
	}
	grpcPort, err := strconv.Atoi(getEnv("GRPC_PORT", "9090"))
	if err != nil {
		return nil, fmt.Errorf("GRPC_PORT: %w", err)
	}

	return &Config{
		ServiceName:  getEnv("SERVICE_NAME", "hello"),
		HTTPPort:     httpPort,
		GRPCPort:     grpcPort,
		OTelEndpoint: getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", ""),
		Environment:  getEnv("ENVIRONMENT", "dev"),
	}, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func (c *Config) HTTPAddr() string {
	return fmt.Sprintf(":%d", c.HTTPPort)
}

func (c *Config) GRPCAddr() string {
	return fmt.Sprintf(":%d", c.GRPCPort)
}
