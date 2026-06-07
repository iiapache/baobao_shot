package rest

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

const testPangleSecret = "test-pangle-secret"

func newAdRewardTestRouter(t *testing.T, fixed time.Time) http.Handler {
	t.Helper()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	registry := adreward.NewRegistry(testPangleSecret, "")
	svc := adreward.NewService(st, ledger, registry, adreward.Options{MinInterval: 0})
	svc.SetNow(func() time.Time { return fixed })
	nonce := adreward.NewNonceGuard()
	nonce.SetNow(func() time.Time { return fixed })
	svc.SetNonceGuard(nonce)
	return NewRouter(nil, st, RouterDeps{AdReward: svc})
}

func TestPangleCallbackGrantsCredits(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	router := newAdRewardTestRouter(t, fixed)
	sign := adreward.ComputeHMACSign(testPangleSecret, "mock-trans-api", "usr_pangle_api")

	body, _ := json.Marshal(map[string]string{
		"user_id":  "usr_pangle_api",
		"trans_id": "mock-trans-api",
		"sign":     sign,
		"extra":    "{}",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/credits/ad-reward/pangle/callback", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	if data["grantedCredits"].(float64) != float64(adreward.DefaultCreditsPerReward) {
		t.Fatalf("grantedCredits = %v", data["grantedCredits"])
	}
}

func TestPangleCallbackRejectsForgedSignature(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	router := newAdRewardTestRouter(t, fixed)

	body, _ := json.Marshal(map[string]string{
		"user_id":  "usr_bad_sig",
		"trans_id": "mock-trans-bad",
		"sign":     "forged-signature",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/credits/ad-reward/pangle/callback", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403; body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "CREDIT_AD_SIGNATURE_INVALID" {
		t.Fatalf("code = %q", resp.Code)
	}
}

func TestClientAdRewardReport(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	router := newAdRewardTestRouter(t, fixed)

	body, _ := json.Marshal(map[string]string{
		"network":     "pangle",
		"placementId":   "slot_client",
		"transId":       "client-trans-001",
		"idfv":          "IDFV-TEST-001",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/credits/ad-reward", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_client_ad")
	req.Header.Set("X-Nonce", "nonce-client-001")
	req.Header.Set("X-Timestamp", fmt.Sprintf("%d", fixed.UnixMilli()))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
}
