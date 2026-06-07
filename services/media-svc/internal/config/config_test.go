package config

import (
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STS_TTL_SECONDS", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.HTTPPort != DefaultHTTPPort {
		t.Fatalf("HTTPPort = %d, want %d", cfg.HTTPPort, DefaultHTTPPort)
	}
	if cfg.GRPCPort != DefaultGRPCPort {
		t.Fatalf("GRPCPort = %d, want %d", cfg.GRPCPort, DefaultGRPCPort)
	}
	if cfg.STSTTLSeconds != DefaultSTSTTLSeconds {
		t.Fatalf("STSTTLSeconds = %d, want %d", cfg.STSTTLSeconds, DefaultSTSTTLSeconds)
	}
	if cfg.ServiceName != "media-svc" {
		t.Fatalf("ServiceName = %q, want media-svc", cfg.ServiceName)
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "redis")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for unsupported backend")
	}
}
