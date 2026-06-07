package iap

import (
	"context"
	"testing"
)

func TestJWSVerifierMockFormat(t *testing.T) {
	v := NewJWSVerifier()
	tx, err := v.Verify(context.Background(), "mock:tx1:prod1:orig1:com.example.app")
	if err != nil {
		t.Fatal(err)
	}
	if tx.TransactionID != "tx1" || tx.ProductID != "prod1" || tx.OriginalTransactionID != "orig1" || tx.BundleID != "com.example.app" {
		t.Fatalf("tx = %+v", tx)
	}
}

func TestJWSVerifierRejectsInvalidToken(t *testing.T) {
	v := NewJWSVerifier()
	_, err := v.Verify(context.Background(), "not-a-jws")
	if err != ErrVerifyFailed {
		t.Fatalf("error = %v, want ErrVerifyFailed", err)
	}
}

func TestProductCatalog(t *testing.T) {
	credits, ok := DefaultProductCatalog.CreditsForProduct("credit_pack_330")
	if !ok || credits != 330 {
		t.Fatalf("credits = %d ok=%v", credits, ok)
	}
}
