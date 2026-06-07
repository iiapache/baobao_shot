package rest

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/query"
	"github.com/baobao/credit-sub-ad-svc/internal/rates"
	"github.com/baobao/credit-sub-ad-svc/internal/signin"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newSignInTestRouter(t *testing.T, fixed time.Time) http.Handler {
	t.Helper()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	catalog, err := rates.LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	signInSvc := signin.NewService(st, ledger)
	signInSvc.SetNow(func() time.Time { return fixed })
	return NewRouter(nil, st, RouterDeps{
		Query:  query.NewService(st, ledger, catalog),
		SignIn: signInSvc,
	})
}

func TestCreditsSignInSuccess(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 15, 0, 0, 0, time.UTC)
	router := newSignInTestRouter(t, fixed)

	req := httptest.NewRequest(http.MethodPost, "/v1/credits/sign-in", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_sign_api")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q", resp.Code)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	if data["grantedCredits"].(float64) != 5 {
		t.Fatalf("grantedCredits = %v", data["grantedCredits"])
	}
	if data["streak"].(float64) != 1 {
		t.Fatalf("streak = %v", data["streak"])
	}
}

func TestCreditsSignInDuplicateReturnsConflict(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 15, 0, 0, 0, time.UTC)
	router := newSignInTestRouter(t, fixed)

	req := httptest.NewRequest(http.MethodPost, "/v1/credits/sign-in", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_dup_api")

	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, req)
	if rec1.Code != http.StatusOK {
		t.Fatalf("first status = %d", rec1.Code)
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req)
	if rec2.Code != http.StatusConflict {
		t.Fatalf("second status = %d, want 409; body=%s", rec2.Code, rec2.Body.String())
	}
	resp, err := decodeAPIResponse(rec2.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "CREDIT_SIGN_IN_DONE" {
		t.Fatalf("code = %q, want CREDIT_SIGN_IN_DONE", resp.Code)
	}
}

func TestCreditsSignInRateLimitViaStore(t *testing.T) {
	st := store.NewMemoryStore()
	fixed := time.Date(2026, 6, 6, 8, 0, 0, 0, time.UTC)
	if _, err := st.RecordSignIn(t.Context(), model.SignInRecord{
		UserID: "usr_pre_signed", Date: fixed, CreditsGranted: 5, Streak: 1,
	}); err != nil {
		t.Fatal(err)
	}

	ledger := credit.NewService(st)
	catalog, err := rates.LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	signInSvc := signin.NewService(st, ledger)
	signInSvc.SetNow(func() time.Time { return fixed })
	router := NewRouter(nil, st, RouterDeps{
		Query:  query.NewService(st, ledger, catalog),
		SignIn: signInSvc,
	})

	req := httptest.NewRequest(http.MethodPost, "/v1/credits/sign-in", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_pre_signed")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want 409", rec.Code)
	}
}

func TestBalanceSignInUnavailableAfterSignIn(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	router := newSignInTestRouter(t, fixed)

	signReq := httptest.NewRequest(http.MethodPost, "/v1/credits/sign-in", nil)
	signReq.Header.Set("Authorization", "Bearer dev:usr_bal_sign")
	signRec := httptest.NewRecorder()
	router.ServeHTTP(signRec, signReq)
	if signRec.Code != http.StatusOK {
		t.Fatalf("sign-in status = %d", signRec.Code)
	}

	balReq := httptest.NewRequest(http.MethodGet, "/v1/credits/balance", nil)
	balReq.Header.Set("Authorization", "Bearer dev:usr_bal_sign")
	balRec := httptest.NewRecorder()
	router.ServeHTTP(balRec, balReq)
	if balRec.Code != http.StatusOK {
		t.Fatalf("balance status = %d", balRec.Code)
	}
	resp, err := decodeAPIResponse(balRec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data := resp.Data.(map[string]any)
	if data["signInAvailable"].(bool) {
		t.Fatalf("signInAvailable = true after sign-in")
	}
}
