package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ServiceName != "hello" {
		t.Fatalf("ServiceName = %q, want hello", cfg.ServiceName)
	}
}
