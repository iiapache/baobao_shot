package config

import (
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STORE_BACKEND", "")

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
	if cfg.ServiceName != "ai-dispatch-svc" {
		t.Fatalf("ServiceName = %q, want ai-dispatch-svc", cfg.ServiceName)
	}
	if cfg.StoreBackend != "memory" {
		t.Fatalf("StoreBackend = %q, want memory", cfg.StoreBackend)
	}
	if !cfg.WorkerEnabled {
		t.Fatal("WorkerEnabled should default true")
	}
	if cfg.WorkerPoolSize != 4 {
		t.Fatalf("WorkerPoolSize = %d, want 4", cfg.WorkerPoolSize)
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORE_BACKEND", "redis")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for unsupported backend")
	}
}
