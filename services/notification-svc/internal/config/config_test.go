package config

import "testing"

func TestResolveAPNSMockDefaults(t *testing.T) {
	t.Setenv("APNS_MOCK", "")
	t.Setenv("ENVIRONMENT", "staging")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.APNSMock {
		t.Fatal("expected APNS mock true for staging by default")
	}

	t.Setenv("ENVIRONMENT", "prod")
	cfg, err = Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.APNSMock {
		t.Fatal("expected APNS mock false for production by default")
	}
}

func TestResolveAPNSMockExplicitOverride(t *testing.T) {
	t.Setenv("ENVIRONMENT", "prod")
	t.Setenv("APNS_MOCK", "true")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.APNSMock {
		t.Fatal("expected explicit APNS_MOCK=true to win")
	}
}

func TestLoadLiveAPNSRequiresCredentialsWhenMockDisabled(t *testing.T) {
	t.Setenv("APNS_MOCK", "false")
	t.Setenv("APNS_KEY_ID", "")
	t.Setenv("APNS_TEAM_ID", "")
	t.Setenv("APNS_PRIVATE_KEY_PEM", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.APNSMock {
		t.Fatal("expected mock disabled")
	}
}
