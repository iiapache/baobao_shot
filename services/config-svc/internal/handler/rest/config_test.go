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

func TestFeaturesRequiresRegion(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	r := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestFeaturesRegionAndRollout(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("X-App-Version", "1.5.0")
	req.Header.Set("Authorization", "Bearer test-token")

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q, want OK", resp.Code)
	}

	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	features, ok := data["features"].(map[string]any)
	if !ok {
		t.Fatal("features missing")
	}
	if _, ok := features["editor.remote_templates"]; !ok {
		t.Fatal("expected editor.remote_templates flag")
	}
	ctx, ok := data["context"].(map[string]any)
	if !ok {
		t.Fatal("context missing")
	}
	if ctx["region"] != "cn" {
		t.Fatalf("region = %v, want cn", ctx["region"])
	}
}

func TestProductConfigEndpoint(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/product", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	if data["version"] != "20250607001" {
		t.Fatalf("version = %v", data["version"])
	}
	configMap, ok := data["config"].(map[string]any)
	if !ok {
		t.Fatal("config missing")
	}
	family, ok := configMap["family"].(map[string]any)
	if !ok || int(family["maxBabies"].(float64)) != 5 {
		t.Fatalf("family = %v", configMap["family"])
	}
}

func TestFeaturesProductLimitsFlags(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req.Header.Set("X-Region", "cn")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	features := data["features"].(map[string]any)
	flag, ok := features["product.limits.family_babies"].(map[string]any)
	if !ok {
		t.Fatal("product.limits.family_babies missing")
	}
	if flag["variant"] != "5" {
		t.Fatalf("variant = %v, want 5", flag["variant"])
	}
}

func TestFeaturesOSTrainingOptOut(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req.Header.Set("X-Region", "os")
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	features, ok := data["features"].(map[string]any)
	if !ok {
		t.Fatal("features missing")
	}
	flag, ok := features["compliance.os_training_opt_out"].(map[string]any)
	if !ok {
		t.Fatal("compliance.os_training_opt_out missing")
	}
	if flag["enabled"] != true {
		t.Fatalf("enabled = %v, want true", flag["enabled"])
	}
	if flag["variant"] != "contract-v1" {
		t.Fatalf("variant = %v, want contract-v1", flag["variant"])
	}
}

func TestFeaturesRolloutFlags(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("X-User-Id-Hash", "5")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	features, ok := data["features"].(map[string]any)
	if !ok {
		t.Fatal("features missing")
	}
	rollout, ok := features["rollout.ai_plays_percent"].(map[string]any)
	if !ok {
		t.Fatal("rollout.ai_plays_percent missing")
	}
	if rollout["rolloutPercent"] != float64(1) {
		t.Fatalf("rolloutPercent = %v, want 1", rollout["rolloutPercent"])
	}
	pricing, ok := features["rollout.pricing_variant"].(map[string]any)
	if !ok {
		t.Fatal("rollout.pricing_variant missing")
	}
	if pricing["variant"] != "control" {
		t.Fatalf("variant = %v, want control", pricing["variant"])
	}
}

func TestAdminKillSwitch(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc", AdminToken: "test-admin"}
	router := NewRouter(cfg, store.NewMemoryStore())

	body := `{"defaultEnabled":false,"rolloutPercent":0}`
	req := httptest.NewRequest(http.MethodPatch, "/v1/admin/features/ai.play.ghibli_kid", strings.NewReader(body))
	req.Header.Set("X-Admin-Token", "test-admin")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("patch status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	req2 := httptest.NewRequest(http.MethodGet, "/v1/config/features", nil)
	req2.Header.Set("X-Region", "cn")
	req2.Header.Set("X-User-Id-Hash", "50")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)

	var resp apiResponse
	if err := json.Unmarshal(rec2.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	features := data["features"].(map[string]any)
	flag := features["ai.play.ghibli_kid"].(map[string]any)
	if flag["enabled"] != false {
		t.Fatalf("enabled = %v, want false after kill-switch", flag["enabled"])
	}
}

func TestPlaysPlaceholder(t *testing.T) {
	cfg := &config.Config{ServiceName: "config-svc"}
	router := NewRouter(cfg, store.NewMemoryStore())

	req := httptest.NewRequest(http.MethodGet, "/v1/config/plays", nil)
	req.Header.Set("X-Region", "cn")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}

	var resp apiResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	if data["source"] != "config-svc" {
		t.Fatalf("source = %v, want config-svc", data["source"])
	}
}
