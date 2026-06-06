package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func createFamilyAndConsent(t *testing.T, router http.Handler, userID string) string {
	t.Helper()
	submitConsent(t, router, userID)
	body, _ := json.Marshal(map[string]string{"name": "测试家庭"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", body, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("create family status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created familySummaryDTO
	_ = json.Unmarshal(data, &created)
	return created.FamilyID
}

func TestBabyCRUDFlow(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_baby_flow"
	seedUser(t, mem, userID)
	familyID := createFamilyAndConsent(t, router, userID)

	createBody, _ := json.Marshal(map[string]any{
		"name":     "小宝",
		"birthday": "2026-03-01",
		"gender":   "male",
	})
	rec := httptest.NewRecorder()
	req := authRequest(http.MethodPost, "/v1/families/"+familyID+"/babies", createBody, userID)
	req.Header.Set("X-Device-Timezone", "Asia/Shanghai")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("create status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created babyDTO
	_ = json.Unmarshal(data, &created)
	if created.BabyID == "" || created.Timezone != "Asia/Shanghai" {
		t.Fatalf("unexpected create: %+v", created)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/families/"+familyID+"/babies", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d", rec.Code)
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	listData, _ := json.Marshal(resp.Data)
	var list struct {
		Items []babyDTO `json:"items"`
	}
	_ = json.Unmarshal(listData, &list)
	if len(list.Items) != 1 {
		t.Fatalf("list items = %d, want 1", len(list.Items))
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/babies/"+created.BabyID, nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("get status = %d", rec.Code)
	}

	patchBody, _ := json.Marshal(map[string]string{"name": "大大宝"})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPatch, "/v1/babies/"+created.BabyID, patchBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("patch status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	patchData, _ := json.Marshal(resp.Data)
	var patched babyDTO
	_ = json.Unmarshal(patchData, &patched)
	if patched.Name != "大大宝" {
		t.Fatalf("name = %q", patched.Name)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/babies/"+created.BabyID, nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("delete status = %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/babies/"+created.BabyID, nil, userID))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("get after delete status = %d, want 404", rec.Code)
	}
}

func TestBabyMultipleProfiles(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_multi_baby"
	seedUser(t, mem, userID)
	familyID := createFamilyAndConsent(t, router, userID)

	for _, name := range []string{"宝宝A", "宝宝B"} {
		body, _ := json.Marshal(map[string]any{"name": name, "birthday": "2026-01-01"})
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+familyID+"/babies", body, userID))
		if rec.Code != http.StatusOK {
			t.Fatalf("create %s status = %d", name, rec.Code)
		}
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/families/"+familyID+"/babies", nil, userID))
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	listData, _ := json.Marshal(resp.Data)
	var list struct {
		Items []babyDTO `json:"items"`
	}
	_ = json.Unmarshal(listData, &list)
	if len(list.Items) != 2 {
		t.Fatalf("items = %d, want 2", len(list.Items))
	}
}

func TestBabyCreateRequiresConsent(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_baby_consent"
	seedUser(t, mem, userID)
	familyID := createFamilyAndConsent(t, router, userID)

	otherID := "usr_no_consent"
	seedUser(t, mem, otherID)
	if err := mem.AddMembership(t.Context(), modelMembership(otherID, familyID)); err != nil {
		t.Fatal(err)
	}

	body, _ := json.Marshal(map[string]any{"name": "小宝", "birthday": "2026-01-01"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+familyID+"/babies", body, otherID))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "ACCOUNT_CONSENT_REQUIRED" {
		t.Fatalf("code = %q", resp.Code)
	}
}

func TestBabyUploadAvatar(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_baby_avatar"
	seedUser(t, mem, userID)
	familyID := createFamilyAndConsent(t, router, userID)

	body, _ := json.Marshal(map[string]any{"name": "头像宝", "birthday": "2026-01-01"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+familyID+"/babies", body, userID))
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created babyDTO
	_ = json.Unmarshal(data, &created)

	rec = httptest.NewRecorder()
	req := authRequest(http.MethodPost, "/v1/babies/"+created.BabyID+"/avatar", []byte("jpeg-bytes"), userID)
	req.Header.Set("Content-Type", "image/jpeg")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("avatar status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	avatarData, _ := json.Marshal(resp.Data)
	var out struct {
		AvatarURL *string `json:"avatarUrl"`
	}
	_ = json.Unmarshal(avatarData, &out)
	if out.AvatarURL == nil || *out.AvatarURL == "" {
		t.Fatalf("avatar url missing: %+v", out)
	}
}

func TestBabyTimezoneFromBirthPlace(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_baby_tz"
	seedUser(t, mem, userID)
	familyID := createFamilyAndConsent(t, router, userID)

	body, _ := json.Marshal(map[string]any{
		"name":       "时区宝",
		"birthday":   "2026-01-01",
		"birthPlace": "纽约",
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+familyID+"/babies", body, userID))
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created babyDTO
	_ = json.Unmarshal(data, &created)
	if created.Timezone != "America/New_York" {
		t.Fatalf("timezone = %q, want America/New_York", created.Timezone)
	}
}

func TestBabyJWTGuestCannotCreate(t *testing.T) {
	secret := "role-middleware-test-secret"
	cfg := &config.Config{
		ServiceName:        "auth-family-svc-test",
		MockAppleVerify:    true,
		JWTSigningSecret:   secret,
	}
	mem := store.NewMemoryStore()
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))

	ctx := t.Context()
	familyID := "fam_baby_guest"
	if _, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: familyID, Name: "guest family", AdminUserID: "usr_admin", Region: "cn",
	}); err != nil {
		t.Fatal(err)
	}
	guestID := "usr_guest"
	seedUser(t, mem, guestID)
	submitConsent(t, router, guestID)
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: guestID, FamilyID: familyID, Role: model.MemberRoleGuest,
	}); err != nil {
		t.Fatal(err)
	}

	body, _ := json.Marshal(map[string]any{"name": "小宝", "birthday": "2026-01-01"})
	token := issueFamilyToken(t, secret, guestID, familyID, "guest")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodPost, "/v1/families/"+familyID+"/babies", body, token))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_FORBIDDEN" {
		t.Fatalf("code = %q, want FAMILY_FORBIDDEN", resp.Code)
	}
}

func modelMembership(userID, familyID string) model.Membership {
	return model.Membership{UserID: userID, FamilyID: familyID, Role: model.MemberRoleFamily}
}
