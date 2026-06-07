package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STORAGE_BACKEND", "")

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
	if cfg.ServiceName != "credit-sub-ad-svc" {
		t.Fatalf("ServiceName = %q, want credit-sub-ad-svc", cfg.ServiceName)
	}
	if cfg.StorageBackend != "memory" {
		t.Fatalf("StorageBackend = %q, want memory", cfg.StorageBackend)
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "redis")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for unsupported backend")
	}
}

func TestLoadPostgresBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "postgres")
	t.Setenv("DATABASE_URL", "postgres://baobao:secret@localhost:5432/baobao?sslmode=disable")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.StorageBackend != "postgres" {
		t.Fatalf("StorageBackend = %q, want postgres", cfg.StorageBackend)
	}
}

func TestLoadAppAttestFlags(t *testing.T) {
	t.Setenv("APP_ATTEST_ENABLED", "true")
	t.Setenv("APP_ATTEST_MOCK", "false")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !cfg.AppAttestEnabled {
		t.Fatal("AppAttestEnabled = false, want true")
	}
	if cfg.AppAttestMock {
		t.Fatal("AppAttestMock = true, want false")
	}
}
