package rest

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newIAPTestRouter(verifier iap.TransactionVerifier) http.Handler {
	st := store.NewMemoryStore()
	iapSvc := iap.NewService(st, credit.NewService(st), verifier, iap.DefaultProductCatalog)
	return NewRouter(nil, st, RouterDeps{IAPVerify: iapSvc})
}

func TestIAPVerifySandboxMock(t *testing.T) {
	router := newIAPTestRouter(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID: "2000000123456789",
			ProductID:     "com.baobao.credits.100",
		},
	})

	body, _ := json.Marshal(map[string]string{
		"transactionId":     "2000000123456789",
		"signedTransaction": "mock:2000000123456789:com.baobao.credits.100",
		"productId":         "com.baobao.credits.100",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/credits/iap-verify", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:usr_iap")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q, want OK", resp.Code)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	if data["grantedCredits"].(float64) != 100 {
		t.Fatalf("grantedCredits = %v, want 100", data["grantedCredits"])
	}
	if data["duplicate"] != nil {
		t.Fatalf("duplicate = %v, want nil/false on first verify", data["duplicate"])
	}
}

func TestIAPVerifyDuplicate(t *testing.T) {
	router := newIAPTestRouter(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID: "tx_dup_api",
			ProductID:     "credit_pack_330",
		},
	})

	body, _ := json.Marshal(map[string]string{
		"transactionId":     "tx_dup_api",
		"signedTransaction": "mock:tx_dup_api:credit_pack_330",
		"productId":         "credit_pack_330",
	})
	doVerify := func() map[string]any {
		req := httptest.NewRequest(http.MethodPost, "/v1/credits/iap-verify", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer dev:usr_dup")
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
		return data
	}

	first := doVerify()
	if first["grantedCredits"].(float64) != 330 {
		t.Fatalf("first grantedCredits = %v", first["grantedCredits"])
	}

	second := doVerify()
	if second["grantedCredits"].(float64) != 0 {
		t.Fatalf("duplicate grantedCredits = %v, want 0", second["grantedCredits"])
	}
	if second["duplicate"].(bool) != true {
		t.Fatalf("duplicate = %v, want true", second["duplicate"])
	}
}

func TestIAPVerifyRequiresAuth(t *testing.T) {
	router := newIAPTestRouter(&iap.MockVerifier{})
	req := httptest.NewRequest(http.MethodPost, "/v1/credits/iap-verify", bytes.NewReader([]byte(`{}`)))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}
