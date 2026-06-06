package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STORAGE_BACKEND", "")
	t.Setenv("MOCK_APPLE_VERIFY", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ServiceName != "auth-family-svc" {
		t.Fatalf("ServiceName = %q, want auth-family-svc", cfg.ServiceName)
	}
	if cfg.HTTPPort != 8001 {
		t.Fatalf("HTTPPort = %d, want 8001", cfg.HTTPPort)
	}
	if cfg.GRPCPort != 9001 {
		t.Fatalf("GRPCPort = %d, want 9001", cfg.GRPCPort)
	}
	if cfg.StorageBackend != "memory" {
		t.Fatalf("StorageBackend = %q, want memory", cfg.StorageBackend)
	}
	if !cfg.MockAppleVerify {
		t.Fatal("MockAppleVerify should default to true in dev")
	}
}

func TestLoadPostgresBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "postgres")
	t.Setenv("DATABASE_URL", "postgres://baobao:secret@localhost:5432/baobao?sslmode=disable")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.StorageBackend != "postgres" {
		t.Fatalf("StorageBackend = %q, want postgres", cfg.StorageBackend)
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "redis")
	_, err := Load()
	if err == nil {
		t.Fatal("expected error for invalid STORAGE_BACKEND")
	}
}
