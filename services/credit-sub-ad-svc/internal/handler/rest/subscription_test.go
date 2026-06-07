package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
)

func newSubscriptionTestRouter(verifier iap.TransactionVerifier) http.Handler {
	st := store.NewMemoryStore()
	subSvc := subscription.NewService(st, verifier, subscription.DefaultProductCatalog)
	return NewRouter(nil, st, RouterDeps{Subscription: subSvc})
}

func TestSubscriptionIAPVerifySandbox(t *testing.T) {
	router := newSubscriptionTestRouter(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "2000000987654321",
			OriginalTransactionID: "orig_api_sub",
			ProductID:             "com.baobao.sub.monthly",
			ExpiresDate:           time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		},
	})

	body, _ := json.Marshal(map[string]string{
		"transactionId":     "2000000987654321",
		"signedTransaction":   "mock:2000000987654321:com.baobao.sub.monthly:orig_api_sub",
		"productId":           "com.baobao.sub.monthly",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/subscriptions/iap-verify", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_sub_api")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	if data["state"] != "active" {
		t.Fatalf("state = %v, want active", data["state"])
	}
	ent, ok := data["entitlements"].(map[string]any)
	if !ok || ent["removeAds"] != true {
		t.Fatalf("entitlements = %v", data["entitlements"])
	}
}

func TestSubscriptionGetMe(t *testing.T) {
	router := newSubscriptionTestRouter(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_me",
			OriginalTransactionID: "orig_me",
			ProductID:             "com.baobao.sub.monthly",
		},
	})

	verifyBody, _ := json.Marshal(map[string]string{
		"transactionId":     "tx_me",
		"signedTransaction":   "mock:tx_me:com.baobao.sub.monthly:orig_me",
		"productId":           "com.baobao.sub.monthly",
	})
	verifyReq := httptest.NewRequest(http.MethodPost, "/v1/subscriptions/iap-verify", bytes.NewReader(verifyBody))
	verifyReq.Header.Set("Authorization", "Bearer dev:usr_me")
	verifyRec := httptest.NewRecorder()
	router.ServeHTTP(verifyRec, verifyReq)
	if verifyRec.Code != http.StatusOK {
		t.Fatalf("verify status = %d", verifyRec.Code)
	}

	meReq := httptest.NewRequest(http.MethodGet, "/v1/subscriptions/me", nil)
	meReq.Header.Set("Authorization", "Bearer dev:usr_me")
	meRec := httptest.NewRecorder()
	router.ServeHTTP(meRec, meReq)
	if meRec.Code != http.StatusOK {
		t.Fatalf("me status = %d, body=%s", meRec.Code, meRec.Body.String())
	}

	resp, err := decodeAPIResponse(meRec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	if data["active"] != true {
		t.Fatalf("active = %v", data["active"])
	}
	if data["cacheTtlSeconds"].(float64) != 600 {
		t.Fatalf("cacheTtlSeconds = %v", data["cacheTtlSeconds"])
	}
}

func TestSubscriptionRequiresAuth(t *testing.T) {
	router := newSubscriptionTestRouter(&iap.MockVerifier{})
	req := httptest.NewRequest(http.MethodGet, "/v1/subscriptions/me", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}
