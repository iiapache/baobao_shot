package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STORAGE_BACKEND", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ServiceName != "feed-svc" {
		t.Fatalf("service = %s", cfg.ServiceName)
	}
	if cfg.HTTPPort != DefaultHTTPPort {
		t.Fatalf("http port = %d", cfg.HTTPPort)
	}
	if cfg.GRPCPort != DefaultGRPCPort {
		t.Fatalf("grpc port = %d", cfg.GRPCPort)
	}
	if cfg.StorageBackend != "memory" {
		t.Fatalf("backend = %s", cfg.StorageBackend)
	}
}
