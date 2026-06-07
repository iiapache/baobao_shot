package iapevent

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

func TestHandlerRefundClawsBackCredits(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	iapSvc := iap.NewService(st, ledger, &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID: "2000000123456789",
			ProductID:     "credit_pack_60",
		},
	}, iap.DefaultProductCatalog)

	verifyResult, err := iapSvc.Verify(ctx, iap.VerifyRequest{
		UserID:            "usr_refund",
		TransactionID:     "2000000123456789",
		SignedTransaction: "mock:2000000123456789:credit_pack_60",
		ProductID:         "credit_pack_60",
	})
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if verifyResult.GrantedCredits != 60 {
		t.Fatalf("granted = %d, want 60", verifyResult.GrantedCredits)
	}

	handler := NewHandler(st, ledger, nil, iap.DefaultProductCatalog, nil)
	if err := handler.Handle(ctx, IAPEvent{
		EventType:        EventIAPRefund,
		NotificationUUID: "notif-refund-test",
		TransactionID:    "2000000123456789",
		ProductID:        "credit_pack_60",
	}); err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	bal, err := ledger.GetBalance(ctx, "usr_refund")
	if err != nil {
		t.Fatalf("GetBalance() error = %v", err)
	}
	if bal.Balance != 0 {
		t.Fatalf("balance = %d, want 0 after refund clawback", bal.Balance)
	}

	if _, err := st.GetLedgerByRef(ctx, "iap_refund", "2000000123456789"); err != nil {
		t.Fatalf("refund ledger missing: %v", err)
	}
}

func TestHandlerRefundIdempotent(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	iapSvc := iap.NewService(st, ledger, &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{TransactionID: "tx_dup_refund", ProductID: "credit_pack_60"},
	}, iap.DefaultProductCatalog)
	if _, err := iapSvc.Verify(ctx, iap.VerifyRequest{
		UserID: "usr_dup", TransactionID: "tx_dup_refund",
		SignedTransaction: "mock", ProductID: "credit_pack_60",
	}); err != nil {
		t.Fatalf("Verify() error = %v", err)
	}

	handler := NewHandler(st, ledger, nil, iap.DefaultProductCatalog, nil)
	evt := IAPEvent{EventType: EventIAPRefund, TransactionID: "tx_dup_refund", ProductID: "credit_pack_60"}

	if err := handler.Handle(ctx, evt); err != nil {
		t.Fatalf("first Handle() error = %v", err)
	}
	if err := handler.Handle(ctx, evt); err != nil {
		t.Fatalf("second Handle() error = %v", err)
	}

	bal, _ := ledger.GetBalance(ctx, "usr_dup")
	if bal.Balance != 0 {
		t.Fatalf("balance = %d, want 0", bal.Balance)
	}
}

func TestHandlerRefundAllowsNegativeBalance(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	iapSvc := iap.NewService(st, ledger, &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{TransactionID: "tx_neg", ProductID: "credit_pack_60"},
	}, iap.DefaultProductCatalog)
	if _, err := iapSvc.Verify(ctx, iap.VerifyRequest{
		UserID: "usr_neg", TransactionID: "tx_neg",
		SignedTransaction: "mock", ProductID: "credit_pack_60",
	}); err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if _, err := ledger.Consume(ctx, "usr_neg", 50, "ai", "task_1"); err != nil {
		t.Fatalf("Consume() error = %v", err)
	}

	handler := NewHandler(st, ledger, nil, iap.DefaultProductCatalog, nil)
	if err := handler.Handle(ctx, IAPEvent{
		EventType: EventIAPRefund, TransactionID: "tx_neg", ProductID: "credit_pack_60",
	}); err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	bal, _ := ledger.GetBalance(ctx, "usr_neg")
	if bal.Balance != -50 {
		t.Fatalf("balance = %d, want -50 (full grant clawback)", bal.Balance)
	}
}

func TestRefundEndToEnd(t *testing.T) {
	ctx := context.Background()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	iapSvc := iap.NewService(st, ledger, &iap.MockVerifier{
		Tx: &iap.VerifiedTransaction{
			TransactionID: "2000000123456789",
			ProductID:     "credit_pack_60",
		},
	}, iap.DefaultProductCatalog)

	if _, err := iapSvc.Verify(ctx, iap.VerifyRequest{
		UserID:            "usr_e2e",
		TransactionID:     "2000000123456789",
		SignedTransaction: "mock:2000000123456789:credit_pack_60",
		ProductID:         "credit_pack_60",
	}); err != nil {
		t.Fatalf("Verify() error = %v", err)
	}

	kafkaPayload, err := json.Marshal(map[string]any{
		"eventType":             "iap.refund",
		"notificationUUID":      "notif-e2e",
		"notificationType":      "REFUND",
		"transactionId":         "2000000123456789",
		"originalTransactionId": "2000000123456789",
		"productId":             "credit_pack_60",
	})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var evt IAPEvent
	if err := json.Unmarshal(kafkaPayload, &evt); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	handler := NewHandler(st, ledger, nil, iap.DefaultProductCatalog, nil)
	if err := handler.Handle(ctx, evt); err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	bal, err := ledger.GetBalance(ctx, "usr_e2e")
	if err != nil {
		t.Fatalf("GetBalance() error = %v", err)
	}
	if bal.Balance != 0 {
		t.Fatalf("balance = %d, want 0", bal.Balance)
	}
}
