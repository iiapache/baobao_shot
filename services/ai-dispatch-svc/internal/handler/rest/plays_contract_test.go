package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Contract tests align handler responses with contracts/openapi (ApiResponse + aiListPlays).

func TestContractAiListPlaysResponseShape(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_contract", "cn"))

	if rec.Code != http.StatusOK {
		t.Fatalf("aiListPlays status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "requestId"} {
		if _, ok := raw[key]; !ok {
			t.Fatalf("aiListPlays response missing OpenAPI required field %q", key)
		}
	}
	if string(raw["code"]) != `"OK"` {
		t.Fatalf("code = %s, want OK", raw["code"])
	}
}

func TestContractAiListPlaysRequiresAuth(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/ai/plays", nil)
	req.Header.Set("X-Region", "cn")
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (OpenAPI bearerAuth)", rec.Code)
	}
}

func TestContractAiListPlaysDataFields(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_contract_data", "cn"))

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	for _, key := range []string{"version", "region", "ttlSeconds", "plays"} {
		if _, ok := data[key]; !ok {
			t.Fatalf("plays catalog data missing field %q", key)
		}
	}

	playsList, ok := data["plays"].([]any)
	if !ok {
		t.Fatal("plays is not an array")
	}
	if len(playsList) == 0 {
		t.Fatal("plays array should not be empty for cn")
	}

	first, ok := playsList[0].(map[string]any)
	if !ok {
		t.Fatal("play item is not an object")
	}
	for _, key := range []string{"id", "name", "kind", "available"} {
		if _, ok := first[key]; !ok {
			t.Fatalf("play item missing field %q", key)
		}
	}
}

func TestContractAiListPlaysVideoDurationTiers(t *testing.T) {
	router := newTestRouter(t)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authPlaysRequest("usr_contract_video", "cn"))

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data := resp.Data.(map[string]any)
	playsList := data["plays"].([]any)

	var videoWalk map[string]any
	for _, raw := range playsList {
		p := raw.(map[string]any)
		if p["id"] == "video_walk" {
			videoWalk = p
			break
		}
	}
	if videoWalk == nil {
		t.Fatal("video_walk not in catalog")
	}

	tiers, ok := videoWalk["durationTiers"].([]any)
	if !ok || len(tiers) != 2 {
		t.Fatalf("durationTiers = %v, want 2 tiers", videoWalk["durationTiers"])
	}
	t0 := tiers[0].(map[string]any)
	if t0["durationSeconds"].(float64) != 5 || t0["creditCost"].(float64) != 60 {
		t.Fatalf("5s tier = %v", t0)
	}
}
