package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("SERVICE_NAME", "")
	t.Setenv("CONFIG_STORAGE", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.HTTPPort != 8009 {
		t.Fatalf("HTTPPort = %d, want 8009", cfg.HTTPPort)
	}
	if cfg.GRPCPort != 9009 {
		t.Fatalf("GRPCPort = %d, want 9009", cfg.GRPCPort)
	}
	if cfg.ServiceName != "config-svc" {
		t.Fatalf("ServiceName = %q, want config-svc", cfg.ServiceName)
	}
	if cfg.Storage.Backend != "memory" {
		t.Fatalf("Storage.Backend = %q, want memory", cfg.Storage.Backend)
	}
}

func TestLoadRedisBackendRequiresURL(t *testing.T) {
	t.Setenv("CONFIG_STORAGE", "redis")
	t.Setenv("REDIS_URL", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Storage.Backend != "redis" {
		t.Fatalf("Storage.Backend = %q, want redis", cfg.Storage.Backend)
	}
}

func TestHTTPAddr(t *testing.T) {
	cfg := &Config{HTTPPort: 8009}
	if got := cfg.HTTPAddr(); got != ":8009" {
		t.Fatalf("HTTPAddr() = %q, want :8009", got)
	}
}
