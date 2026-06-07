package subscription

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newTestSubscriptionService(verifier iap.TransactionVerifier) *Service {
	st := store.NewMemoryStore()
	svc := NewService(st, verifier, DefaultProductCatalog)
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixed }
	svc.newID = func() string { return "sub_test" }
	return svc
}

func TestVerifyCreatesActiveSubscription(t *testing.T) {
	svc := newTestSubscriptionService(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "2000000987654321",
			OriginalTransactionID: "orig_sub_1",
			ProductID:             "com.baobao.sub.monthly",
			PurchaseDate:          time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
			ExpiresDate:           time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
			AutoRenewEnabled:      true,
		},
	})
	ctx := context.Background()

	result, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_sub",
		TransactionID:     "2000000987654321",
		SignedTransaction: "mock:2000000987654321:com.baobao.sub.monthly:orig_sub_1",
		ProductID:         "com.baobao.sub.monthly",
	})
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if result.State != model.SubscriptionActive {
		t.Fatalf("state = %s, want active", result.State)
	}
	if !result.Entitlements.RemoveAds {
		t.Fatal("expected removeAds entitlement")
	}
	if result.Duplicate {
		t.Fatal("expected first verify not duplicate")
	}

	me, err := svc.GetMe(ctx, "usr_sub")
	if err != nil {
		t.Fatal(err)
	}
	if !me.Active || me.State != "active" {
		t.Fatalf("me = %+v", me)
	}
	if me.CacheTTLSeconds != 600 {
		t.Fatalf("cache ttl = %d, want 600", me.CacheTTLSeconds)
	}
}

func TestVerifyCreatesTrialSubscription(t *testing.T) {
	svc := newTestSubscriptionService(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_trial",
			OriginalTransactionID: "orig_trial",
			ProductID:             "com.baobao.sub.monthly",
			IsTrial:               true,
			AutoRenewEnabled:      true,
		},
	})

	result, err := svc.Verify(context.Background(), VerifyRequest{
		UserID:            "usr_trial",
		TransactionID:     "tx_trial",
		SignedTransaction: "mock:tx_trial:com.baobao.sub.monthly:orig_trial",
		ProductID:         "com.baobao.sub.monthly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.State != model.SubscriptionTrial {
		t.Fatalf("state = %s, want trial", result.State)
	}
}

func TestVerifyRenewalAndDuplicate(t *testing.T) {
	svc := newTestSubscriptionService(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_renew_1",
			OriginalTransactionID: "orig_renew",
			ProductID:             "com.baobao.sub.monthly",
			PurchaseDate:          time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
			ExpiresDate:           time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		},
	})
	ctx := context.Background()
	firstReq := VerifyRequest{
		UserID:            "usr_renew",
		TransactionID:     "tx_renew_1",
		SignedTransaction: "mock:tx_renew_1:com.baobao.sub.monthly:orig_renew",
		ProductID:         "com.baobao.sub.monthly",
	}
	if _, err := svc.Verify(ctx, firstReq); err != nil {
		t.Fatal(err)
	}

	svc.verifier = &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_renew_2",
			OriginalTransactionID: "orig_renew",
			ProductID:             "com.baobao.sub.monthly",
			PurchaseDate:          time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
			ExpiresDate:           time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		},
	}
	renewReq := VerifyRequest{
		UserID:            "usr_renew",
		TransactionID:     "tx_renew_2",
		SignedTransaction: "mock:tx_renew_2:com.baobao.sub.monthly:orig_renew",
		ProductID:         "com.baobao.sub.monthly",
	}
	renewed, err := svc.Verify(ctx, renewReq)
	if err != nil {
		t.Fatal(err)
	}
	if renewed.State != model.SubscriptionActive {
		t.Fatalf("renewed state = %s, want active", renewed.State)
	}
	if renewed.PeriodEnd != time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC) {
		t.Fatalf("periodEnd = %s", renewed.PeriodEnd)
	}

	dup, err := svc.Verify(ctx, renewReq)
	if err != nil {
		t.Fatal(err)
	}
	if !dup.Duplicate {
		t.Fatal("expected duplicate on repeated transaction")
	}
}

func TestVerifyRepurchaseFromExpired(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_rebuy",
			OriginalTransactionID: "orig_rebuy",
			ProductID:             "com.baobao.sub.monthly",
			ExpiresDate:           time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		},
	}, DefaultProductCatalog)
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	svc.newID = func() string { return "sub_rebuy" }

	ctx := context.Background()
	if err := st.CreateSubscription(ctx, model.Subscription{
		ID:                    "sub_rebuy",
		UserID:                "usr_rebuy",
		OriginalTransactionID: "orig_rebuy",
		SKU:                   "com.baobao.sub.monthly",
		PeriodStart:           time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		PeriodEnd:             time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC),
		State:                 model.SubscriptionExpired,
		AutoRenew:             false,
		LastEventAt:           time.Date(2026, 5, 2, 0, 0, 0, 0, time.UTC),
	}); err != nil {
		t.Fatal(err)
	}

	result, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_rebuy",
		TransactionID:     "tx_rebuy",
		SignedTransaction: "mock:tx_rebuy:com.baobao.sub.monthly:orig_rebuy",
		ProductID:         "com.baobao.sub.monthly",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.State != model.SubscriptionActive {
		t.Fatalf("state = %s, want active", result.State)
	}
}

func TestApplyEventRefund(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, &iap.MockVerifier{}, DefaultProductCatalog)
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	ctx := context.Background()
	if err := st.CreateSubscription(ctx, model.Subscription{
		ID:                    "sub_refund",
		UserID:                "usr_refund",
		OriginalTransactionID: "orig_refund",
		SKU:                   "com.baobao.sub.monthly",
		PeriodStart:           time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
		PeriodEnd:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		State:                 model.SubscriptionActive,
		AutoRenew:             true,
		LastEventAt:           time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
	}); err != nil {
		t.Fatal(err)
	}

	sub, err := svc.ApplyEvent(ctx, "orig_refund", EventRefund)
	if err != nil {
		t.Fatal(err)
	}
	if sub.State != model.SubscriptionRefunded {
		t.Fatalf("state = %s, want refunded", sub.State)
	}

	me, err := svc.GetMe(ctx, "usr_refund")
	if err != nil {
		t.Fatal(err)
	}
	if me.Active {
		t.Fatal("refunded subscription should not be active")
	}
}

func TestRunExpiryScanTransitions(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st, &iap.MockVerifier{}, DefaultProductCatalog)
	now := time.Date(2026, 6, 20, 0, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return now }
	ctx := context.Background()

	cases := []struct {
		id    string
		state model.SubscriptionState
		end   time.Time
		auto  bool
		want  model.SubscriptionState
	}{
		{id: "sub_active_no_renew", state: model.SubscriptionActive, end: time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC), auto: false, want: model.SubscriptionExpired},
		{id: "sub_active_renew", state: model.SubscriptionActive, end: time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC), auto: true, want: model.SubscriptionGrace},
		{id: "sub_grace_expired", state: model.SubscriptionGrace, end: time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC), auto: true, want: model.SubscriptionExpired},
	}

	for _, tc := range cases {
		if err := st.CreateSubscription(ctx, model.Subscription{
			ID:                    tc.id,
			UserID:                "usr_cron",
			OriginalTransactionID: "orig_" + tc.id,
			SKU:                   "com.baobao.sub.monthly",
			PeriodStart:           tc.end.Add(-30 * 24 * time.Hour),
			PeriodEnd:             tc.end,
			State:                 tc.state,
			AutoRenew:             tc.auto,
			LastEventAt:           tc.end,
		}); err != nil {
			t.Fatal(err)
		}
	}

	n, err := svc.RunExpiryScan(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if n != len(cases) {
		t.Fatalf("updated = %d, want %d", n, len(cases))
	}

	for _, tc := range cases {
		sub, err := st.GetSubscriptionByOriginalTransactionID(ctx, "orig_"+tc.id)
		if err != nil {
			t.Fatal(err)
		}
		if sub.State != tc.want {
			t.Fatalf("%s state = %s, want %s", tc.id, sub.State, tc.want)
		}
	}
}

func TestGetMeNoSubscription(t *testing.T) {
	svc := newTestSubscriptionService(&iap.MockVerifier{})
	me, err := svc.GetMe(context.Background(), "usr_none")
	if err != nil {
		t.Fatal(err)
	}
	if me.Active || me.State != "none" {
		t.Fatalf("me = %+v", me)
	}
}

func TestVerifyUserMismatch(t *testing.T) {
	svc := newTestSubscriptionService(&iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_user_sub",
			OriginalTransactionID: "orig_user_sub",
			ProductID:             "com.baobao.sub.monthly",
		},
	})
	ctx := context.Background()
	req := VerifyRequest{
		UserID:            "usr_a",
		TransactionID:     "tx_user_sub",
		SignedTransaction: "mock:tx_user_sub:com.baobao.sub.monthly:orig_user_sub",
		ProductID:         "com.baobao.sub.monthly",
	}
	if _, err := svc.Verify(ctx, req); err != nil {
		t.Fatal(err)
	}

	svc.verifier = &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID:         "tx_user_sub_2",
			OriginalTransactionID: "orig_user_sub",
			ProductID:             "com.baobao.sub.monthly",
		},
	}
	_, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_b",
		TransactionID:     "tx_user_sub_2",
		SignedTransaction: "mock:tx_user_sub_2:com.baobao.sub.monthly:orig_user_sub",
		ProductID:         "com.baobao.sub.monthly",
	})
	if !errors.Is(err, ErrUserMismatch) {
		t.Fatalf("error = %v, want ErrUserMismatch", err)
	}
}
