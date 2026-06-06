package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/store"
)

func jwtAuthRequest(t *testing.T, method, target string, body []byte, token string) *http.Request {
	t.Helper()
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Region", "cn")
	req.Header.Set("Content-Type", "application/json")
	return req
}

func issueFamilyToken(t *testing.T, secret, userID, familyID, role string) string {
	t.Helper()
	issuer := auth.NewTokenIssuer(secret)
	pair, err := issuer.Issue(auth.IssueTokenInput{
		UserID:   userID,
		Region:   "cn",
		DeviceID: "role-test-device",
		Families: []auth.FamilyClaim{{FamilyID: familyID, Role: role}},
	})
	if err != nil {
		t.Fatal(err)
	}
	return pair.AccessToken
}

func roleTestRouter(t *testing.T) (http.Handler, string) {
	t.Helper()
	secret := "role-middleware-test-secret"
	cfg := &config.Config{
		ServiceName:      "auth-family-svc-test",
		MockAppleVerify:    true,
		JWTSigningSecret: secret,
	}
	mem := store.NewMemoryStore()
	return NewRouter(cfg, store.NewBackend(cfg, mem, nil)), secret
}

func TestJWTTransferRejectedForNonAdmin(t *testing.T) {
	router, secret := roleTestRouter(t)
	familyID := "fam_transfer_gate"

	token := issueFamilyToken(t, secret, "usr_member", familyID, "family")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodPost, "/v1/families/"+familyID+"/transfer", nil, token))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_FORBIDDEN" {
		t.Fatalf("code = %q, want FAMILY_FORBIDDEN", resp.Code)
	}
}

func TestJWTTransferAllowedForAdmin(t *testing.T) {
	router, secret := roleTestRouter(t)
	familyID := "fam_transfer_admin"

	token := issueFamilyToken(t, secret, "usr_admin", familyID, "admin")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodPost, "/v1/families/"+familyID+"/transfer", nil, token))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "COMMON_BAD_PARAM" {
		t.Fatalf("code = %q, want COMMON_BAD_PARAM", resp.Code)
	}
}

func TestJWTGuestUpdateRejected(t *testing.T) {
	router, secret := roleTestRouter(t)
	familyID := "fam_guest_write"

	body, _ := json.Marshal(map[string]string{"name": "访客改名"})
	token := issueFamilyToken(t, secret, "usr_guest", familyID, "guest")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodPatch, "/v1/families/"+familyID, body, token))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_FORBIDDEN" {
		t.Fatalf("code = %q, want FAMILY_FORBIDDEN", resp.Code)
	}
}

func TestJWTDeleteInvitationRequiresAdminClaim(t *testing.T) {
	router, secret := roleTestRouter(t)
	familyID := "fam_invite_admin"

	token := issueFamilyToken(t, secret, "usr_family", familyID, "family")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodPost, "/v1/families/"+familyID+"/invitations", nil, token))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("create invite status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_FORBIDDEN" {
		t.Fatalf("code = %q, want FAMILY_FORBIDDEN", resp.Code)
	}
}

func TestJWTNonMemberGetsAuthForbidden(t *testing.T) {
	router, secret := roleTestRouter(t)
	familyID := "fam_not_member"

	token := issueFamilyToken(t, secret, "usr_outsider", "fam_other", "admin")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, jwtAuthRequest(t, http.MethodGet, "/v1/families/"+familyID, nil, token))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "AUTH_FORBIDDEN" {
		t.Fatalf("code = %q, want AUTH_FORBIDDEN", resp.Code)
	}
}
