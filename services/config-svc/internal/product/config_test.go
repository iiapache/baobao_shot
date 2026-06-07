package product

import "testing"

func TestLoadProductConfig(t *testing.T) {
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Version != "20250607001" {
		t.Fatalf("version = %q, want 20250607001", cfg.Version)
	}
	if cfg.Family.MaxMembers != 8 || cfg.Family.MaxBabies != 5 {
		t.Fatalf("family limits = %+v, want members=8 babies=5", cfg.Family)
	}
	if cfg.Invite.CodeLength != 6 || cfg.Invite.TTLHours != 24 || cfg.Invite.MaxUses != 8 {
		t.Fatalf("invite = %+v", cfg.Invite)
	}
	if cfg.Credits.Signup != 100 || cfg.Credits.AdRewardPerView != 5 {
		t.Fatalf("credits = %+v", cfg.Credits)
	}
	if len(cfg.AIVideo.DurationTiersSeconds) != 2 || cfg.AIVideo.TrialDurationSeconds != nil {
		t.Fatalf("ai video = %+v", cfg.AIVideo)
	}
	if cfg.ScopeV1.PregnancyMode {
		t.Fatal("pregnancy mode should be deferred in V1.0")
	}
}
