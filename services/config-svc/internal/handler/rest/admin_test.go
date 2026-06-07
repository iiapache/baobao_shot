package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/baobao/config-svc/internal/config"
	"github.com/baobao/config-svc/internal/store"
)

func TestAdminRequiresToken(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc", AdminToken: "secret"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodPatch, "/v1/admin/features/ai.play.video_walk",
		strings.NewReader(`{"defaultEnabled":false}`))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestAdminSetRolloutPercent(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc", AdminToken: "secret"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodPatch, "/v1/admin/features/rollout.ai_plays_percent",
		strings.NewReader(`{"rolloutPercent":25,"variant":"25"}`))
	req.Header.Set("X-Admin-Token", "secret")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	req2 := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req2.Header.Set("X-Region", "cn")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)

	var resp apiResponse
	if err := json.Unmarshal(rec2.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	features := data["features"].(map[string]any)
	rollout := features["rollout.ai_plays_percent"].(map[string]any)
	if rollout["rolloutPercent"] != float64(25) {
		t.Fatalf("rolloutPercent = %v, want 25", rollout["rolloutPercent"])
	}
}
