package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("SERVICE_NAME", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.HTTPPort != 8080 {
		t.Fatalf("HTTPPort = %d, want 8080", cfg.HTTPPort)
	}
	if cfg.GRPCPort != 9090 {
		t.Fatalf("GRPCPort = %d, want 9090", cfg.GRPCPort)
	}
	if cfg.ServiceName != "template" {
		t.Fatalf("ServiceName = %q, want template", cfg.ServiceName)
	}
}

func TestHTTPAddr(t *testing.T) {
	cfg := &Config{HTTPPort: 8080}
	if got := cfg.HTTPAddr(); got != ":8080" {
		t.Fatalf("HTTPAddr() = %q, want :8080", got)
	}
}
