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

func TestLoadAppleAuthMockPrefersAppleAuthMockEnv(t *testing.T) {
	t.Setenv("APPLE_AUTH_MOCK", "false")
	t.Setenv("MOCK_APPLE_VERIFY", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.MockAppleVerify {
		t.Fatal("APPLE_AUTH_MOCK=false should disable mock mode")
	}
}

func TestValidateRequiresBundleIDWhenLiveAppleAuth(t *testing.T) {
	cfg := &Config{MockAppleVerify: false, AppleBundleID: ""}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected validation error for missing APPLE_BUNDLE_ID")
	}
}

func TestValidateAllowsMockWithoutBundleID(t *testing.T) {
	cfg := &Config{MockAppleVerify: true, AppleBundleID: ""}
	if err := cfg.Validate(); err != nil {
		t.Fatal(err)
	}
}
