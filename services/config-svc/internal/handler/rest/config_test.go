package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
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
