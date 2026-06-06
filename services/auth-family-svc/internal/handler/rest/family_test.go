package rest

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func newTestRouter(t *testing.T) (http.Handler, *store.MemoryStore) {
	t.Helper()
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	backend := store.NewBackend(cfg, mem, nil)
	return NewRouter(cfg, backend), mem
}

func authRequest(method, target string, body []byte, userID string) *http.Request {
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("Content-Type", "application/json")
	return req
}

func TestFamilyCreateListGetUpdateDelete(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_family_flow"
	seedUser(t, mem, userID)
	submitConsent(t, router, userID)

	createBody, _ := json.Marshal(map[string]string{"name": "我们的家"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", createBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("create status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("create response = %+v err = %v", resp, err)
	}
	data, _ := json.Marshal(resp.Data)
	var created familySummaryDTO
	if err := json.Unmarshal(data, &created); err != nil {
		t.Fatalf("decode create data: %v", err)
	}
	if created.FamilyID == "" || created.Name != "我们的家" || created.Role != "admin" {
		t.Fatalf("unexpected create data: %+v", created)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/families", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d", rec.Code)
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	listData, _ := json.Marshal(resp.Data)
	var list struct {
		Items []familySummaryDTO `json:"items"`
	}
	_ = json.Unmarshal(listData, &list)
	if len(list.Items) != 1 {
		t.Fatalf("list items = %d, want 1", len(list.Items))
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/families/"+created.FamilyID, nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("get status = %d body = %s", rec.Code, rec.Body.String())
	}

	patchBody, _ := json.Marshal(map[string]string{"name": "新名字"})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPatch, "/v1/families/"+created.FamilyID, patchBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("patch status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	patchData, _ := json.Marshal(resp.Data)
	var patched familySummaryDTO
	_ = json.Unmarshal(patchData, &patched)
	if patched.Name != "新名字" {
		t.Fatalf("patched name = %q", patched.Name)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/families/"+created.FamilyID, nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("delete status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/families/"+created.FamilyID, nil, userID))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("get after delete status = %d, want 404", rec.Code)
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_NOT_FOUND" {
		t.Fatalf("code = %q, want FAMILY_NOT_FOUND", resp.Code)
	}
}

func TestFamilyCreateLimit(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_create_limit"
	seedUser(t, mem, userID)
	submitConsent(t, router, userID)

	for i := 0; i < 2; i++ {
		body, _ := json.Marshal(map[string]string{"name": "家" + string(rune('A'+i))})
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", body, userID))
		if rec.Code != http.StatusOK {
			t.Fatalf("create #%d status = %d body = %s", i+1, rec.Code, rec.Body.String())
		}
	}

	body, _ := json.Marshal(map[string]string{"name": "第三个"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", body, userID))
	if rec.Code != http.StatusConflict {
		t.Fatalf("third create status = %d, want 409", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_CREATE_LIMIT" {
		t.Fatalf("code = %q, want FAMILY_CREATE_LIMIT", resp.Code)
	}
}

func TestFamilyJoinLimit(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))
	userID := "usr_join_limit"

	ctx := context.Background()
	// Seed three families owned by others; user joins all three.
	for i := 0; i < 3; i++ {
		owner := "usr_owner_" + string(rune('A'+i))
		familyID := "fam_seed_" + string(rune('A'+i))
		if _, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
			ID:          familyID,
			Name:        "seed",
			AdminUserID: owner,
			Region:      "cn",
		}); err != nil {
			t.Fatalf("seed family: %v", err)
		}
		if err := mem.AddMembership(ctx, model.Membership{
			UserID:   userID,
			FamilyID: familyID,
			Role:     model.MemberRoleFamily,
		}); err != nil {
			t.Fatalf("add membership: %v", err)
		}
	}

	seedUser(t, mem, userID)
	submitConsent(t, router, userID)

	body, _ := json.Marshal(map[string]string{"name": "超限家庭"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", body, userID))
	if rec.Code != http.StatusConflict {
		t.Fatalf("create status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_JOIN_LIMIT" {
		t.Fatalf("code = %q, want FAMILY_JOIN_LIMIT", resp.Code)
	}
}

func TestFamilyDeleteNotAdmin(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))

	ctx := context.Background()
	family, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_admin_only", Name: "admin home", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/families/"+family.ID, nil, "usr_member"))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("delete by non-member status = %d, want 404", rec.Code)
	}

	if err := mem.AddMembership(ctx, model.Membership{
		UserID: "usr_member", FamilyID: family.ID, Role: model.MemberRoleFamily,
	}); err != nil {
		t.Fatal(err)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/families/"+family.ID, nil, "usr_member"))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("delete by member status = %d, want 403", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_NOT_ADMIN" {
		t.Fatalf("code = %q, want FAMILY_NOT_ADMIN", resp.Code)
	}
}

func TestFamilyUnauthorized(t *testing.T) {
	router, _ := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/families", nil)
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("code = %q, want AUTH_UNAUTHORIZED", resp.Code)
	}
}

func TestDevTokenParsing(t *testing.T) {
	router, mem := newTestRouter(t)
	seedUser(t, mem, "usr_dev")
	submitConsent(t, router, "usr_dev")
	body, _ := json.Marshal(map[string]string{"name": "dev token home"})

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/families", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev")
	req.Header.Set("X-Region", "cn")
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("dev token status = %d body = %s", rec.Code, rec.Body.String())
	}
}
