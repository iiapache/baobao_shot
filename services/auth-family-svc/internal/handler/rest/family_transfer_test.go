package rest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/family"
	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestFamilyTransferAdminHTTP(t *testing.T) {
	router, mem := newTestRouter(t)
	ctx := context.Background()

	adminID := "usr_http_transfer_admin"
	targetID := "usr_http_transfer_target"
	seedUser(t, mem, adminID)
	seedUser(t, mem, targetID)
	submitConsent(t, router, adminID)

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_http_transfer", Name: "HTTP转让家", AdminUserID: adminID, Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: targetID, FamilyID: f.ID, Role: model.MemberRoleFamily, Nickname: "妈妈",
	}); err != nil {
		t.Fatal(err)
	}

	body, _ := json.Marshal(map[string]string{"targetUserId": targetID})
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+f.ID+"/transfer", body, adminID))
	if rec.Code != http.StatusOK {
		t.Fatalf("transfer status = %d body = %s", rec.Code, rec.Body.String())
	}

	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "OK" {
		t.Fatalf("code = %q", resp.Code)
	}
	data, _ := json.Marshal(resp.Data)
	var result transferAdminResponseDTO
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	if result.NewAdminUserID != targetID {
		t.Fatalf("new admin = %q, want %q", result.NewAdminUserID, targetID)
	}
}

func TestFamilyTakeoverHTTP(t *testing.T) {
	router, mem := newTestRouter(t)
	ctx := context.Background()

	adminID := "usr_http_takeover_admin"
	member1 := "usr_http_takeover_m1"
	member2 := "usr_http_takeover_m2"
	member3 := "usr_http_takeover_m3"
	seedUser(t, mem, adminID)
	seedUser(t, mem, member1)
	seedUser(t, mem, member2)
	seedUser(t, mem, member3)

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_http_takeover", Name: "HTTP接管家", AdminUserID: adminID, Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, memberID := range []string{member1, member2, member3} {
		if err := mem.AddMembership(ctx, model.Membership{
			UserID: memberID, FamilyID: f.ID, Role: model.MemberRoleFamily,
		}); err != nil {
			t.Fatal(err)
		}
	}
	inactiveAt := time.Now().UTC().Add(-31 * 24 * time.Hour)
	if err := mem.SetUserLastSeen(ctx, adminID, inactiveAt); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+f.ID+"/takeover", nil, member1))
	if rec.Code != http.StatusOK {
		t.Fatalf("initiate status = %d body = %s", rec.Code, rec.Body.String())
	}

	voteBody, _ := json.Marshal(map[string]string{"choice": "approve"})
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+f.ID+"/takeover", voteBody, member2))
	if rec.Code != http.StatusOK {
		t.Fatalf("vote status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	data, _ := json.Marshal(resp.Data)
	var result family.TakeoverResult
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	if result.Status != string(model.TakeoverStatusObjectionPeriod) {
		t.Fatalf("status = %q, want objection_period", result.Status)
	}
}

func TestFamilyTakeoverRejectsActiveAdminHTTP(t *testing.T) {
	router, mem := newTestRouter(t)
	ctx := context.Background()

	adminID := "usr_http_active_admin"
	memberID := "usr_http_active_member"
	seedUser(t, mem, adminID)
	seedUser(t, mem, memberID)

	f, err := mem.CreateFamily(ctx, store.CreateFamilyInput{
		ID: "fam_http_active", Name: "活跃管理员", AdminUserID: adminID, Region: "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := mem.AddMembership(ctx, model.Membership{
		UserID: memberID, FamilyID: f.ID, Role: model.MemberRoleFamily,
	}); err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authRequest(http.MethodPost, "/v1/families/"+f.ID+"/takeover", nil, memberID))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
	}
	resp, _ := decodeAPIResponse(rec.Body.Bytes())
	if resp.Code != "FAMILY_ADMIN_ACTIVE" {
		t.Fatalf("code = %q, want FAMILY_ADMIN_ACTIVE", resp.Code)
	}
}
