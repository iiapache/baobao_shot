package iap

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func newTestIAPService(verifier TransactionVerifier) *Service {
	st := store.NewMemoryStore()
	svc := NewService(st, credit.NewService(st), verifier, DefaultProductCatalog)
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC) }
	svc.newID = func() string { return "iap_test" }
	return svc
}

func TestVerifyGrantsCredits(t *testing.T) {
	svc := newTestIAPService(&MockVerifier{
		Tx: &VerifiedTransaction{
			TransactionID:         "2000000123456789",
			OriginalTransactionID: "2000000123456789",
			ProductID:             "com.baobao.credits.100",
		},
	})
	ctx := context.Background()

	result, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_1",
		TransactionID:     "2000000123456789",
		SignedTransaction: "mock:2000000123456789:com.baobao.credits.100",
		ProductID:         "com.baobao.credits.100",
	})
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if result.Duplicate {
		t.Fatal("expected first verify not duplicate")
	}
	if result.GrantedCredits != 100 {
		t.Fatalf("grantedCredits = %d, want 100", result.GrantedCredits)
	}
	if result.BalanceAfter != 100 {
		t.Fatalf("balanceAfter = %d, want 100", result.BalanceAfter)
	}
	if result.LedgerID == "" {
		t.Fatal("expected ledgerId")
	}

	receipt, err := svc.store.GetIAPReceiptByTransactionID(ctx, "2000000123456789")
	if err != nil {
		t.Fatalf("GetIAPReceiptByTransactionID() error = %v", err)
	}
	if receipt.UserID != "usr_1" || receipt.ProductID != "com.baobao.credits.100" {
		t.Fatalf("receipt = %+v", receipt)
	}
}

func TestVerifyDuplicateReturnsZeroGrant(t *testing.T) {
	svc := newTestIAPService(&MockVerifier{
		Tx: &VerifiedTransaction{
			TransactionID: "tx_dup",
			ProductID:     "credit_pack_330",
		},
	})
	ctx := context.Background()
	req := VerifyRequest{
		UserID:            "usr_dup",
		TransactionID:     "tx_dup",
		SignedTransaction: "mock:tx_dup:credit_pack_330",
		ProductID:         "credit_pack_330",
	}

	first, err := svc.Verify(ctx, req)
	if err != nil {
		t.Fatal(err)
	}
	if first.GrantedCredits != 330 {
		t.Fatalf("first granted = %d, want 330", first.GrantedCredits)
	}

	second, err := svc.Verify(ctx, req)
	if err != nil {
		t.Fatalf("duplicate Verify() error = %v", err)
	}
	if !second.Duplicate {
		t.Fatal("expected duplicate=true")
	}
	if second.GrantedCredits != 0 {
		t.Fatalf("duplicate grantedCredits = %d, want 0", second.GrantedCredits)
	}
	if second.BalanceAfter != 330 {
		t.Fatalf("duplicate balanceAfter = %d, want 330", second.BalanceAfter)
	}
	if second.LedgerID != first.LedgerID {
		t.Fatalf("ledgerId mismatch: %s vs %s", second.LedgerID, first.LedgerID)
	}
}

func TestVerifyUserMismatch(t *testing.T) {
	svc := newTestIAPService(&MockVerifier{
		Tx: &VerifiedTransaction{
			TransactionID: "tx_user",
			ProductID:     "credit_pack_60",
		},
	})
	ctx := context.Background()
	req := VerifyRequest{
		UserID:            "usr_a",
		TransactionID:     "tx_user",
		SignedTransaction: "mock:tx_user:credit_pack_60",
		ProductID:         "credit_pack_60",
	}
	if _, err := svc.Verify(ctx, req); err != nil {
		t.Fatal(err)
	}

	_, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_b",
		TransactionID:     "tx_user",
		SignedTransaction: "mock:tx_user:credit_pack_60",
		ProductID:         "credit_pack_60",
	})
	if !errors.Is(err, ErrUserMismatch) {
		t.Fatalf("Verify() error = %v, want ErrUserMismatch", err)
	}
}

func TestVerifyJWSPayloadParsing(t *testing.T) {
	svc := newTestIAPService(NewJWSVerifier())
	ctx := context.Background()

	payload := "eyJ0cmFuc2FjdGlvbklkIjoidHhfandzIiwib3JpZ2luYWxUcmFuc2FjdGlvbklkIjoidHhfandzIiwicHJvZHVjdElkIjoiY3JlZGl0X3BhY2tfNjAifQ"
	signed := "header." + payload + ".signature"

	result, err := svc.Verify(ctx, VerifyRequest{
		UserID:            "usr_jws",
		TransactionID:     "tx_jws",
		SignedTransaction: signed,
		ProductID:         "credit_pack_60",
	})
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if result.GrantedCredits != 60 {
		t.Fatalf("grantedCredits = %d, want 60", result.GrantedCredits)
	}
}

func TestVerifyUnknownProduct(t *testing.T) {
	svc := newTestIAPService(&MockVerifier{
		Tx: &VerifiedTransaction{
			TransactionID: "tx_unknown",
			ProductID:     "unknown.product",
		},
	})
	_, err := svc.Verify(context.Background(), VerifyRequest{
		UserID:            "usr_1",
		TransactionID:     "tx_unknown",
		SignedTransaction: "mock:tx_unknown:unknown.product",
		ProductID:         "unknown.product",
	})
	if !errors.Is(err, ErrProductUnknown) {
		t.Fatalf("Verify() error = %v, want ErrProductUnknown", err)
	}
}
