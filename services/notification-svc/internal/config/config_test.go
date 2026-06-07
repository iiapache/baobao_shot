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
	if cfg.HTTPPort != DefaultHTTPPort {
		t.Fatalf("HTTPPort = %d, want %d", cfg.HTTPPort, DefaultHTTPPort)
	}
	if cfg.GRPCPort != DefaultGRPCPort {
		t.Fatalf("GRPCPort = %d, want %d", cfg.GRPCPort, DefaultGRPCPort)
	}
	if cfg.ServiceName != "notification-svc" {
		t.Fatalf("ServiceName = %q", cfg.ServiceName)
	}
	if cfg.StorageBackend != "memory" {
		t.Fatalf("StorageBackend = %q", cfg.StorageBackend)
	}
	if !cfg.APNSSandbox {
		t.Fatal("expected APNS sandbox default true")
	}
	if cfg.KafkaEnabled() {
		t.Fatal("kafka should be disabled by default")
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "redis")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for invalid backend")
	}
}
