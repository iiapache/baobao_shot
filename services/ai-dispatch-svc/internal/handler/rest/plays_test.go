package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"github.com/baobao/ai-dispatch-svc/internal/filing"
	"github.com/baobao/ai-dispatch-svc/internal/plays"
)

func newTestRouter(t *testing.T) http.Handler {
	t.Helper()
	m, err := plays.LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	cfg := &config.Config{
		ServiceName:      "ai-dispatch-svc-test",
		JWTSigningSecret: "dev-only-change-me",
	}
	catalog := plays.NewCatalog(m, configclient.NewStub(nil))
	return NewRouter(cfg, RouterDeps{PlayCatalog: catalog})
}

func authPlaysRequest(userID, region string) *http.Request {
	req := httptest.NewRequest(http.MethodGet, "/v1/ai/plays", nil)
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("X-Region", region)
	req.Header.Set("X-App-Version", "1.5.0")
	return req
}

func TestPlaysListCN(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_plays_cn", "cn"))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q, want OK", resp.Code)
	}

	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	if data["region"] != "cn" {
		t.Fatalf("region = %v, want cn", data["region"])
	}
	playsList, ok := data["plays"].([]any)
	if !ok || len(playsList) == 0 {
		t.Fatal("expected non-empty plays list")
	}
}

func TestPlaysListRequiresAuth(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/ai/plays", nil)
	req.Header.Set("X-Region", "cn")
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestPlaysListRequiresRegion(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/ai/plays", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_no_region")
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestPlaysListCreditCostOnImagePlay(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_credit", "cn"))

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data := resp.Data.(map[string]any)
	playsList := data["plays"].([]any)

	var ghibli map[string]any
	for _, raw := range playsList {
		p := raw.(map[string]any)
		if p["id"] == "ghibli_kid" {
			ghibli = p
			break
		}
	}
	if ghibli == nil {
		t.Fatal("ghibli_kid not found")
	}
	if ghibli["creditCost"].(float64) != 8 {
		t.Fatalf("creditCost = %v, want 8", ghibli["creditCost"])
	}
}

func TestPlaysListGrayDisabledPlay(t *testing.T) {
	m, err := plays.LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	stub := configclient.NewStub(nil)
	stub.SetFeature("ai.play.photo_restore", false)
	cfg := &config.Config{ServiceName: "ai-dispatch-svc-test", JWTSigningSecret: "dev-only-change-me"}
	router := NewRouter(cfg, RouterDeps{PlayCatalog: plays.NewCatalog(m, stub)})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_gray", "cn"))

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data := resp.Data.(map[string]any)
	playsList := data["plays"].([]any)
	for _, raw := range playsList {
		p := raw.(map[string]any)
		if p["id"] == "photo_restore" {
			t.Fatal("photo_restore should be hidden by gray flag")
		}
	}
}

func TestPlaysListFilingFilteredCN(t *testing.T) {
	m, err := plays.LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	store := filing.NewStore(filing.Bindings{"SeedreamAdapter": {}}, "test")
	cfg := &config.Config{ServiceName: "ai-dispatch-svc-test", JWTSigningSecret: "dev-only-change-me"}
	router := NewRouter(cfg, RouterDeps{PlayCatalog: plays.NewCatalogWithFilings(m, configclient.NewStub(nil), store)})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_filing_cn", "cn"))

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data := resp.Data.(map[string]any)
	playsList := data["plays"].([]any)
	for _, raw := range playsList {
		p := raw.(map[string]any)
		if p["id"] == "seedream_style" {
			t.Fatal("seedream_style should be hidden without valid CN filing")
		}
	}
}

func TestPlaysListJSONShape(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_shape", "os"))

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "requestId"} {
		if _, ok := raw[key]; !ok {
			t.Fatalf("response missing OpenAPI required field %q", key)
		}
	}
}
