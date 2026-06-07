package asn

import (
	"encoding/base64"
	"encoding/json"
	"testing"
)

func TestParseMockASNRefund(t *testing.T) {
	n, err := ParseSignedPayload("mock-asn:REFUND:notif-001:mock:2000000123456789:credit_pack_60")
	if err != nil {
		t.Fatalf("ParseSignedPayload() error = %v", err)
	}
	if n.NotificationType != "REFUND" || n.NotificationUUID != "notif-001" {
		t.Fatalf("notification = %+v", n)
	}

	tx, err := ParseTransactionInfo(n.SignedTransactionInfo, nil)
	if err != nil {
		t.Fatalf("ParseTransactionInfo() error = %v", err)
	}
	if tx.TransactionID != "2000000123456789" || tx.ProductID != "credit_pack_60" {
		t.Fatalf("tx = %+v", tx)
	}
}

func TestParseJWSPayload(t *testing.T) {
	payload := outerPayload{
		NotificationType: "REVOKE",
		NotificationUUID: "uuid-123",
	}
	payload.Data.SignedTransactionInfo = "mock:tx1:prod1"
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(raw)
	token := "header." + encoded + ".sig"

	n, err := ParseSignedPayload(token)
	if err != nil {
		t.Fatalf("ParseSignedPayload() error = %v", err)
	}
	if n.NotificationType != "REVOKE" || n.NotificationUUID != "uuid-123" {
		t.Fatalf("notification = %+v", n)
	}
}

func TestParseSignedPayloadEmpty(t *testing.T) {
	if _, err := ParseSignedPayload(""); err == nil {
		t.Fatal("expected error for empty payload")
	}
}
