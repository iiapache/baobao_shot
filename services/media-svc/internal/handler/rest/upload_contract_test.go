package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Contract tests align handler responses with contracts/openapi (ApiResponse + upload operations).

func TestContractUploadInitResponseShape(t *testing.T) {
	router, _ := newTestRouter(t)
	body, _ := json.Marshal(map[string]any{
		"purpose": "ai-input",
		"items": []map[string]any{{
			"clientRef": "c1",
			"kind":      "image",
			"mime":      "image/heic",
			"size":      100,
		}},
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/init", body, "usr_contract"))
	if rec.Code != http.StatusOK {
		t.Fatalf("uploadInit status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "requestId"} {
		if _, ok := raw[key]; !ok {
			t.Fatalf("uploadInit response missing OpenAPI required field %q", key)
		}
	}
	if string(raw["code"]) != `"OK"` {
		t.Fatalf("code = %s, want OK", raw["code"])
	}
}

func TestContractUploadCompleteResponseShape(t *testing.T) {
	router, _ := newTestRouter(t)
	userID := "usr_contract_complete"

	initBody, _ := json.Marshal(map[string]any{
		"purpose": "ai-input",
		"items":   []map[string]string{{"clientRef": "c1", "mime": "image/png"}},
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/init", initBody, userID))
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var initData map[string]any
	_ = json.Unmarshal(data, &initData)
	uploadID := initData["uploadId"].(string)

	completeBody, _ := json.Marshal(map[string]string{"uploadId": uploadID})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/complete", completeBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("uploadComplete status = %d, want 200", rec.Code)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "requestId"} {
		if _, ok := raw[key]; !ok {
			t.Fatalf("uploadComplete response missing OpenAPI required field %q", key)
		}
	}
}

func TestContractUploadInitPurposeEnum(t *testing.T) {
	router, _ := newTestRouter(t)
	for _, purpose := range []string{"ai-input", "post-item"} {
		payload := map[string]any{
			"purpose": purpose,
			"items":   []map[string]string{{"clientRef": "c1", "mime": "image/jpeg"}},
		}
		if purpose == "post-item" {
			payload["familyId"] = "fam_01"
		}
		body, _ := json.Marshal(payload)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/uploads/init", body, "usr_enum"))
		if rec.Code != http.StatusOK {
			t.Fatalf("purpose=%s status=%d body=%s", purpose, rec.Code, rec.Body.String())
		}
	}
}

func TestContractUploadInitRequiresAuth(t *testing.T) {
	router, _ := newTestRouter(t)
	body := bytes.NewReader([]byte(`{"purpose":"ai-input","items":[{"clientRef":"c1"}]}`))
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/uploads/init", body)
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (OpenAPI bearerAuth)", rec.Code)
	}
}
