package rest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func TestBackupProviderFlow(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_backup_flow"
	seedUser(t, mem, userID)

	expiresAt := time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC).Format(time.RFC3339)
	bindBody, _ := json.Marshal(map[string]any{
		"kind":              model.BackupProviderKindBaiduPan,
		"accessToken":       "baidu-access",
		"refreshToken":      "baidu-refresh",
		"expiresAt":         expiresAt,
		"providerAccountId": "baidu-user-1",
		"metadata":          map[string]string{"scope": "basic"},
	})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/backup/providers", bindBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("bind status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil || resp.Code != "OK" {
		t.Fatalf("bind response = %+v err = %v", resp, err)
	}
	data, _ := json.Marshal(resp.Data)
	var bound backupProviderDTO
	if err := json.Unmarshal(data, &bound); err != nil {
		t.Fatalf("decode bind data: %v", err)
	}
	if bound.ID == "" || bound.Kind != model.BackupProviderKindBaiduPan {
		t.Fatalf("unexpected bind data: %+v", bound)
	}
	if _, hasToken := resp.Data.(map[string]any)["accessToken"]; hasToken {
		t.Fatal("response must not expose access token")
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/backup/providers", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	listData, _ := json.Marshal(resp.Data)
	var list struct {
		Items []backupProviderDTO `json:"items"`
	}
	_ = json.Unmarshal(listData, &list)
	if len(list.Items) != 1 {
		t.Fatalf("list items = %d, want 1", len(list.Items))
	}
	if raw, err := mem.ListBackupProviders(context.Background(), userID); err != nil || len(raw) != 1 {
		t.Fatalf("raw providers: %+v err=%v", raw, err)
	} else if raw[0].AccessToken == "baidu-access" {
		t.Fatal("access token stored in plaintext")
	}

	icloudBody, _ := json.Marshal(map[string]string{"kind": model.BackupProviderKindICloud})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/backup/providers", icloudBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("bind icloud status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/backup/providers", nil, userID))
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	listData, _ = json.Marshal(resp.Data)
	_ = json.Unmarshal(listData, &list)
	if len(list.Items) != 2 {
		t.Fatalf("list items = %d, want 2", len(list.Items))
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/backup/providers/"+bound.ID, nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("delete status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/backup/providers/"+bound.ID, nil, userID))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("delete again status = %d, want 404", rec.Code)
	}
}

func TestBackupStatusFlow(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_backup_status_flow"
	seedUser(t, mem, userID)

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodGet, "/v1/backup/status", nil, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("get empty status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	statusData, _ := json.Marshal(resp.Data)
	var empty backupStatusDTO
	_ = json.Unmarshal(statusData, &empty)
	if empty.FailureCount != 0 {
		t.Fatalf("empty failureCount = %d, want 0", empty.FailureCount)
	}

	attemptedAt := time.Date(2026, 6, 6, 8, 0, 0, 0, time.UTC).Format(time.RFC3339)
	failBody, _ := json.Marshal(map[string]any{
		"success":     false,
		"attemptedAt": attemptedAt,
		"errorCode":   "BACKUP_AUTH_REVOKED",
	})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/backup/status", failBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("report failure status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	statusData, _ = json.Marshal(resp.Data)
	var failed backupStatusDTO
	_ = json.Unmarshal(statusData, &failed)
	if failed.FailureCount != 1 || failed.LastErrorCode == nil || *failed.LastErrorCode != "BACKUP_AUTH_REVOKED" {
		t.Fatalf("unexpected failed status: %+v", failed)
	}

	successBody, _ := json.Marshal(map[string]any{
		"success":     true,
		"attemptedAt": time.Date(2026, 6, 6, 9, 0, 0, 0, time.UTC).Format(time.RFC3339),
	})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/backup/status", successBody, userID))
	if rec.Code != http.StatusOK {
		t.Fatalf("report success status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	statusData, _ = json.Marshal(resp.Data)
	var success backupStatusDTO
	_ = json.Unmarshal(statusData, &success)
	if success.FailureCount != 0 || success.LastSuccessAt == nil {
		t.Fatalf("unexpected success status: %+v", success)
	}
}

func TestBackupUnauthorized(t *testing.T) {
	router, _ := newTestRouter(t)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/backup/providers", nil)
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestBackupBindInvalidKind(t *testing.T) {
	router, mem := newTestRouter(t)
	userID := "usr_backup_invalid"
	seedUser(t, mem, userID)

	body, _ := json.Marshal(map[string]string{"kind": "dropbox", "accessToken": "x"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/backup/providers", body, userID))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "BACKUP_INVALID_PROVIDER" {
		t.Fatalf("code = %q, want BACKUP_INVALID_PROVIDER", resp.Code)
	}
}
