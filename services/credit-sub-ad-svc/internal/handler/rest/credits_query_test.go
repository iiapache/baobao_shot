package rest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/query"
	"github.com/baobao/credit-sub-ad-svc/internal/rates"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newQueryTestRouter(t *testing.T) http.Handler {
	t.Helper()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	catalog, err := rates.LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	querySvc := query.NewService(st, ledger, catalog)
	iapSvc := iap.NewService(st, ledger, &iap.MockVerifier{}, iap.DefaultProductCatalog)
	return NewRouter(nil, st, RouterDeps{
		IAPVerify: iapSvc,
		Query:     querySvc,
	})
}

func TestCreditsGetBalance(t *testing.T) {
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	ctx := t.Context()
	if _, err := ledger.Grant(ctx, "usr_bal", 42, "signup", "welcome"); err != nil {
		t.Fatal(err)
	}

	catalog, err := rates.LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	router := NewRouter(nil, st, RouterDeps{Query: query.NewService(st, ledger, catalog)})

	req := httptest.NewRequest(http.MethodGet, "/v1/credits/balance", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_bal")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatalf("data type = %T", resp.Data)
	}
	if data["balance"].(float64) != 42 {
		t.Fatalf("balance = %v", data["balance"])
	}
	if data["signInAvailable"].(bool) != true {
		t.Fatalf("signInAvailable = %v, want true", data["signInAvailable"])
	}
}

func TestCreditsListTransactionsPagination(t *testing.T) {
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	ctx := t.Context()
	for i := 0; i < 3; i++ {
		if _, err := ledger.Grant(ctx, "usr_txn", 10, "iap", "tx_"+string(rune('a'+i))); err != nil {
			t.Fatal(err)
		}
	}

	catalog, err := rates.LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	router := NewRouter(nil, st, RouterDeps{Query: query.NewService(st, ledger, catalog)})

	req := httptest.NewRequest(http.MethodGet, "/v1/credits/transactions?limit=2", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_txn")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("page1 status = %d, body=%s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	page1, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("unexpected data type")
	}
	items, ok := page1["items"].([]any)
	if !ok || len(items) != 2 {
		t.Fatalf("page1 items = %#v", page1["items"])
	}
	nextCursor, ok := page1["nextCursor"].(string)
	if !ok || nextCursor == "" {
		t.Fatalf("nextCursor = %#v", page1["nextCursor"])
	}

	req2 := httptest.NewRequest(http.MethodGet, "/v1/credits/transactions?limit=2&cursor="+nextCursor, nil)
	req2.Header.Set("Authorization", "Bearer dev:usr_txn")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusOK {
		t.Fatalf("page2 status = %d, body=%s", rec2.Code, rec2.Body.String())
	}
	resp2, err := decodeAPIResponse(rec2.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	page2 := resp2.Data.(map[string]any)
	items2 := page2["items"].([]any)
	if len(items2) != 1 {
		t.Fatalf("page2 items len = %d, want 1", len(items2))
	}
	if page2["nextCursor"] != nil {
		t.Fatalf("page2 nextCursor = %#v, want nil", page2["nextCursor"])
	}
}

func TestCreditsListTransactionsInvalidCursor(t *testing.T) {
	router := newQueryTestRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/v1/credits/transactions?cursor=not-valid", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_bad")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "COMMON_BAD_PARAM" {
		t.Fatalf("code = %q", resp.Code)
	}
}

func TestCreditsGetRates(t *testing.T) {
	router := newQueryTestRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/v1/credits/rates", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_rates")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("unexpected data")
	}
	if data["version"].(string) == "" {
		t.Fatal("missing version")
	}
	plays, ok := data["plays"].([]any)
	if !ok || len(plays) == 0 {
		t.Fatalf("plays = %#v", data["plays"])
	}
}

func TestSubscriptionsListProducts(t *testing.T) {
	router := newQueryTestRouter(t)

	req := httptest.NewRequest(http.MethodGet, "/v1/subscriptions/products", nil)
	req.Header.Set("Authorization", "Bearer dev:usr_sub")
	req.Header.Set("X-Region", "cn")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(resp.Data)
	var data struct {
		Region   string `json:"region"`
		Products []struct {
			ProductID string `json:"productId"`
		} `json:"products"`
	}
	if err := json.Unmarshal(raw, &data); err != nil {
		t.Fatal(err)
	}
	if data.Region != "cn" {
		t.Fatalf("region = %q", data.Region)
	}
	if len(data.Products) != 4 {
		t.Fatalf("products len = %d, want 4", len(data.Products))
	}
}

func TestCreditsQueryRequiresAuth(t *testing.T) {
	router := newQueryTestRouter(t)
	paths := []string{
		"/v1/credits/balance",
		"/v1/credits/transactions",
		"/v1/credits/rates",
		"/v1/subscriptions/products",
	}
	for _, path := range paths {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("%s status = %d, want 401", path, rec.Code)
		}
	}
}

func TestMemoryListLedgerEntries(t *testing.T) {
	st := store.NewMemoryStore()
	ctx := t.Context()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	for i := 0; i < 3; i++ {
		entry := model.LedgerEntry{
			ID: "led_"+string(rune('a'+i)), UserID: "usr_page", Type: model.EntryGrant, Amount: 1,
			RefKind: "test", RefID: "ref_" + string(rune('a'+i)), BalanceAfter: int64(i + 1),
			CreatedAt: now.Add(time.Duration(i) * time.Minute),
		}
		if err := st.ApplyLedgerEntry(ctx, store.ApplyLedgerInput{
			Entry: entry, ExpectedVersion: int64(i), NewBalance: int64(i + 1),
		}); err != nil {
			t.Fatal(err)
		}
	}

	page1, err := st.ListLedgerEntries(ctx, store.ListLedgerInput{UserID: "usr_page", Limit: 2})
	if err != nil {
		t.Fatal(err)
	}
	if len(page1.Items) != 2 || page1.NextCursor == "" {
		t.Fatalf("page1 = %+v", page1)
	}

	page2, err := st.ListLedgerEntries(ctx, store.ListLedgerInput{
		UserID: "usr_page", Limit: 2, Cursor: page1.NextCursor,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(page2.Items) != 1 || page2.NextCursor != "" {
		t.Fatalf("page2 = %+v", page2)
	}
}
