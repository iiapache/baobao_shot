package rest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestInvitationCreateJoinRevoke(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{
		ServiceName:         "auth-family-svc-test",
		MockAppleVerify:     true,
		InviteSigningSecret: "test-secret",
		AppScheme:           "baobao://invite",
	}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))
	ctx := context.Background()

	adminID := "usr_invite_admin"
	seedUser(t, mem, adminID)
	submitConsent(t, router, adminID)
	createBody, _ := json.Marshal(map[string]string{"name": "邀请测试家"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families", createBody, adminID))
	if rec.Code != http.StatusOK {
		t.Fatalf("create family status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var created familySummaryDTO
	_ = json.Unmarshal(data, &created)

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+created.FamilyID+"/invitations", nil, adminID))
	if rec.Code != http.StatusOK {
		t.Fatalf("create invite status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	inviteData, _ := json.Marshal(resp.Data)
	var inviteResp struct {
		Code      string `json:"code"`
		MaxUses   int    `json:"maxUses"`
		QRPayload struct {
			Scheme string `json:"scheme"`
			Code   string `json:"code"`
			Sig    string `json:"sig"`
		} `json:"qrPayload"`
	}
	if err := json.Unmarshal(inviteData, &inviteResp); err != nil {
		t.Fatal(err)
	}
	if len(inviteResp.Code) != family.InviteCodeLength {
		t.Fatalf("code = %q", inviteResp.Code)
	}
	if inviteResp.MaxUses != family.InviteMaxUses {
		t.Fatalf("maxUses = %d", inviteResp.MaxUses)
	}
	if inviteResp.QRPayload.Scheme != "baobao://invite" || inviteResp.QRPayload.Code != inviteResp.Code {
		t.Fatalf("qrPayload = %+v", inviteResp.QRPayload)
	}

	joinBody, _ := json.Marshal(map[string]string{"relation": "grandma", "nickname": "外婆"})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/"+inviteResp.Code+"/join", joinBody, "usr_joiner"))
	if rec.Code != http.StatusOK {
		t.Fatalf("join status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	joinData, _ := json.Marshal(resp.Data)
	var joined joinInvitationResponseDTO
	if err := json.Unmarshal(joinData, &joined); err != nil {
		t.Fatal(err)
	}
	if joined.FamilyID != created.FamilyID || joined.Role != "family" || joined.JoinedAt == "" {
		t.Fatalf("joined = %+v", joined)
	}

	detail, err := mem.GetFamilyDetail(ctx, created.FamilyID, "usr_joiner")
	if err != nil {
		t.Fatal(err)
	}
	if len(detail.Members) != 2 {
		t.Fatalf("members = %d, want 2", len(detail.Members))
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodDelete, "/v1/families/"+created.FamilyID+"/invitations/"+inviteResp.Code, nil, adminID))
	if rec.Code != http.StatusOK {
		t.Fatalf("revoke status = %d body = %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/"+inviteResp.Code+"/join", joinBody, "usr_joiner2"))
	if rec.Code != http.StatusGone {
		t.Fatalf("join after revoke status = %d, want 410", rec.Code)
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_INVITE_EXPIRED" {
		t.Fatalf("code = %q, want FAMILY_INVITE_EXPIRED", resp.Code)
	}
}

func TestInvitationJoinExpiredAndUsedUp(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))
	ctx := context.Background()

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_invite_err", Name: "x", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	expired, err := mem.CreateInviteCode(ctx, store.CreateInviteCodeInput{
		Code: "111111", FamilyID: f.ID, CreatedBy: "usr_admin",
		ExpireAt: time.Now().UTC().Add(-time.Hour), MaxUses: family.InviteMaxUses,
	})
	if err != nil {
		t.Fatal(err)
	}
	usedUp, err := mem.CreateInviteCode(ctx, store.CreateInviteCodeInput{
		Code: "222222", FamilyID: f.ID, CreatedBy: "usr_admin",
		ExpireAt: time.Now().UTC().Add(family.InviteTTL), MaxUses: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := mem.JoinViaInvite(ctx, store.JoinViaInviteInput{
		Code: usedUp.Code, UserID: "usr_first", Nickname: "first",
	}); err != nil {
		t.Fatal(err)
	}

	joinBody, _ := json.Marshal(map[string]string{"relation": "dad"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/"+expired.Code+"/join", joinBody, "usr_joiner"))
	if rec.Code != http.StatusGone {
		t.Fatalf("expired status = %d, want 410", rec.Code)
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_INVITE_EXPIRED" {
		t.Fatalf("code = %q", resp.Code)
	}

	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/"+usedUp.Code+"/join", joinBody, "usr_joiner"))
	if rec.Code != http.StatusConflict {
		t.Fatalf("used up status = %d, want 409", rec.Code)
	}
	resp, _ = decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_INVITE_USED_UP" {
		t.Fatalf("code = %q", resp.Code)
	}
}

func TestInvitationJoinLimit(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))
	ctx := context.Background()
	joinerID := "usr_join_limit_handler"

	for i := 0; i < family.MaxFamiliesJoined; i++ {
		owner := "owner_" + string(rune('A'+i))
		familyID := "fam_limit_" + string(rune('A'+i))
		if _, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
			ID: familyID, Name: "x", AdminUserID: owner, Region: "cn",
		}); err != nil {
			t.Fatal(err)
		}
		if err := mem.AddMembership(ctx, model.Membership{
			UserID: joinerID, FamilyID: familyID, Role: model.MemberRoleFamily,
		}); err != nil {
			t.Fatal(err)
		}
	}

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_new_invite", Name: "新", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	invite, err := mem.CreateInviteCode(ctx, store.CreateInviteCodeInput{
		Code: "333333", FamilyID: f.ID, CreatedBy: "usr_admin",
		ExpireAt: time.Now().UTC().Add(family.InviteTTL), MaxUses: family.InviteMaxUses,
	})
	if err != nil {
		t.Fatal(err)
	}

	joinBody, _ := json.Marshal(map[string]string{"relation": "mom"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/"+invite.Code+"/join", joinBody, joinerID))
	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_JOIN_LIMIT" {
		t.Fatalf("code = %q, want FAMILY_JOIN_LIMIT", resp.Code)
	}
}

func TestInvitationCreateNotAdmin(t *testing.T) {
	mem := store.NewMemoryStore()
	cfg := &config.Config{ServiceName: "auth-family-svc-test", MockAppleVerify: true}
	router := NewRouter(cfg, store.NewBackend(cfg, mem, nil))
	ctx := context.Background()

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_not_admin", Name: "x", AdminUserID: "usr_admin", Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+f.ID+"/invitations", nil, "usr_stranger"))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
}

func TestInvitationJoinMissingRelation(t *testing.T) {
	router, _ := newTestRouter(t)
	joinBody, _ := json.Marshal(map[string]string{"nickname": "外婆"})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/invitations/123456/join", joinBody, "usr_joiner"))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}
