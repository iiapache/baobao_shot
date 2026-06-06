package feature

import "testing"

func TestUserIDHashStable(t *testing.T) {
	h1 := UserIDHash("usr_abc")
	h2 := UserIDHash("usr_abc")
	if h1 != h2 {
		t.Fatalf("hash not stable: %d vs %d", h1, h2)
	}
	if h1 < 0 || h1 >= 100 {
		t.Fatalf("hash out of range: %d", h1)
	}
}

func TestEvaluateRegionGate(t *testing.T) {
	def := Definition{
		Key:            "ai.storybook",
		DefaultEnabled: true,
		Regions:        []string{"cn"},
		RolloutPercent: 100,
	}

	cn := Evaluate(def, EvalContext{Region: "cn", UserID: "usr_1"})
	if !cn.Enabled {
		t.Fatal("expected enabled for cn")
	}

	os := Evaluate(def, EvalContext{Region: "os", UserID: "usr_1"})
	if os.Enabled {
		t.Fatal("expected disabled for os")
	}
}

func TestEvaluateRolloutPercent(t *testing.T) {
	def := Definition{
		Key:            "editor.remote_templates",
		DefaultEnabled: true,
		RolloutPercent: 50,
	}

	enabled := 0
	for i := 0; i < 200; i++ {
		userID := "usr_rollout_" + string(rune('a'+i%26))
		if Evaluate(def, EvalContext{Region: "cn", UserID: userID}).Enabled {
			enabled++
		}
	}
	if enabled == 0 || enabled == 200 {
		t.Fatalf("rollout produced all/none enabled: %d/200", enabled)
	}
}

func TestEvaluateMinAppVersion(t *testing.T) {
	def := Definition{
		Key:            "feed.alpha",
		DefaultEnabled: true,
		RolloutPercent: 100,
		MinAppVersion:  "2.0.0",
	}

	old := Evaluate(def, EvalContext{Region: "cn", UserID: "u1", AppVersion: "1.9.9"})
	if old.Enabled {
		t.Fatal("expected disabled for old app version")
	}

	new := Evaluate(def, EvalContext{Region: "cn", UserID: "u1", AppVersion: "2.0.0"})
	if !new.Enabled {
		t.Fatal("expected enabled for min app version")
	}
}
