package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/account"
	"github.com/baobao/auth-family-svc/internal/consent"
	"github.com/baobao/auth-family-svc/internal/store"
)

func seedUser(t *testing.T, mem *store.MemoryStore, userID string) {
	t.Helper()
	_, err := mem.CreateUser(t.Context(), store.CreateUserInput{
		ID:       userID,
		AppleSub: "apple-" + userID,
		Region:   "cn",
		Nickname: "测试用户",
	})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
}

func submitConsent(t *testing.T, router http.Handler, userID string) {
	t.Helper()
	body, _ := json.Marshal(map[string]any{
		"version":  consent.CurrentConsentVersion,
		"accepted": true,
	})
	rec := httptest.NewRecorder()
	req := authRequest(http.MethodPost, "/v1/account/consents/child-data", body, userID)
	req.Header.Set("X-Device-Id", "test-device")
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("submit consent status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestAccountGetMeWithoutConsent(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_me_no_consent"
	seedUser(t, mem, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/account/me", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("response = %+v err = %v", resp, err)
	}
	data, _ := json.Marshal(resp.Data)
	var profile userProfileDTO
	if err := json.Unmarshal(data, &profile); err != nil {
		t.Fatalf("decode profile: %v", err)
	}
	if profile.Consents["childData"] {
		t.Fatal("childData should be false before consent")
	}
}

func TestAccountSubmitChildDataConsentAndGetMe(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_me_with_consent"
	seedUser(t, mem, userID)

	submitConsent(t, router, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/account/me", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("get me status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var profile userProfileDTO
	_ = json.Unmarshal(data, &profile)
	if !profile.Consents["childData"] {
		t.Fatal("childData should be true after consent")
	}
}

func TestAccountSubmitChildDataConsentValidation(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_consent_validation"
	seedUser(t, mem, userID)

	body, _ := json.Marshal(map[string]any{
		"version":  "old",
		"accepted": true,
	})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/consents/child-data", body, userID))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want 422", rec.Code)
	}

	body, _ = json.Marshal(map[string]any{
		"version":  consent.CurrentConsentVersion,
		"accepted": false,
	})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/consents/child-data", body, userID))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("reject status = %d, want 422", rec.Code)
	}
}

func TestFamilyCreateRequiresChildConsent(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_family_consent"
	seedUser(t, mem, userID)

	createBody, _ := json.Marshal(map[string]string{"name": "我们的家"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", createBody, userID))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d body = %s, want 422", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "ACCOUNT_CONSENT_REQUIRED" {
		t.Fatalf("code = %q, want ACCOUNT_CONSENT_REQUIRED", resp.Code)
	}

	submitConsent(t, router, userID)

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", createBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("after consent status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestAccountDeleteAndCancelWithinGracePeriod(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_delete_cancel"
	seedUser(t, mem, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/account", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("delete status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("delete response = %+v err = %v", resp, err)
	}
	data, _ := json.Marshal(resp.Data)
	var deletion deletionData
	if err := json.Unmarshal(data, &deletion); err != nil {
		t.Fatal(err)
	}
	if deletion.RevokeBefore == "" || deletion.ScheduledAt == "" {
		t.Fatal("expected schedule fields in delete response")
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/account/me", nil, userID))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("get me after delete status = %d, want 404", rec.Code)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/cancel-deletion", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("cancel status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/account/me", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("get me after cancel status = %d body = %s", rec.Code, rec.Body.String())
	}
}

func TestAccountDeleteIdempotent(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_delete_idempotent"
	seedUser(t, mem, userID)

	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, authRequest(http.MethodDelete, "/v1/account", nil, userID))
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, authRequest(http.MethodDelete, "/v1/account", nil, userID))
	if rec1.Code != http.StatusOK || rec2.Code != http.StatusOK {
		t.Fatalf("status codes = %d / %d", rec1.Code, rec2.Code)
	}

	resp1, _ := decodeAPIResponse(rec1.Body.Bytes())
	resp2, _ := decodeAPIResponse(rec2.Body.Bytes())
	data1, _ := json.Marshal(resp1.Data)
	data2, _ := json.Marshal(resp2.Data)
	var d1, d2 deletionData
	_ = json.Unmarshal(data1, &d1)
	_ = json.Unmarshal(data2, &d2)
	if d1.ScheduledAt != d2.ScheduledAt {
		t.Fatalf("scheduledAt mismatch: %s vs %s", d1.ScheduledAt, d2.ScheduledAt)
	}
}

func TestAccountCancelDeletionNotPending(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_no_deletion"
	seedUser(t, mem, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/cancel-deletion", nil, userID))
	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want 409", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "ACCOUNT_DELETION_NOT_PENDING" {
		t.Fatalf("code = %q", resp.Code)
	}
}

func TestAccountCancelDeletionExpired(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_deletion_expired"
	seedUser(t, mem, userID)

	requestedAt := time.Now().UTC().Add(-8 * 24 * time.Hour)
	scheduledAt := time.Now().UTC().Add(-time.Hour)
	if _, err := mem.UpsertDeletion(t.Context(), userID, requestedAt, scheduledAt); err != nil {
		t.Fatal(err)
	}
	if err := mem.SoftDeleteUser(t.Context(), userID, requestedAt); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/cancel-deletion", nil, userID))
	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "ACCOUNT_DELETION_EXPIRED" {
		t.Fatalf("code = %q, want ACCOUNT_DELETION_EXPIRED", resp.Code)
	}
}

func TestAccountRequestExport(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_export"
	seedUser(t, mem, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/account/export", nil, userID))
	if rec.Code != http.StatusAccepted {
		t.Fatalf("export status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, authRequest(http.MethodPost, "/v1/account/export", nil, userID))
	if rec2.Code != http.StatusAccepted {
		t.Fatalf("second export status = %d", rec2.Code)
	}

	resp1, _ := decodeAPIResponse(rec.Body.Bytes())
	resp2, _ := decodeAPIResponse(rec2.Body.Bytes())
	data1, _ := json.Marshal(resp1.Data)
	data2, _ := json.Marshal(resp2.Data)
	var e1, e2 exportRequestData
	_ = json.Unmarshal(data1, &e1)
	_ = json.Unmarshal(data2, &e2)
	if e1.ExportID != e2.ExportID {
		t.Fatalf("exportId mismatch: %s vs %s", e1.ExportID, e2.ExportID)
	}
}

func TestAccountDeletionGracePeriodConstant(t *testing.T) {
	if account.DeletionGracePeriod != 7*24*time.Hour {
		t.Fatalf("grace period = %v", account.DeletionGracePeriod)
	}
}
