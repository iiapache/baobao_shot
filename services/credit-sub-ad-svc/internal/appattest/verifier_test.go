package appattest

import (
	"encoding/base64"
	"testing"
)

func TestDisabledVerifierAllowsMissingPayload(t *testing.T) {
	v := DisabledVerifier{}
	if err := v.Verify(VerifyInput{TransactionID: "tx", ProductID: "sku"}); err != nil {
		t.Fatalf("expected nil, got %v", err)
	}
}

func TestMockVerifierAllowsMissingPayload(t *testing.T) {
	v := MockVerifier{}
	if err := v.Verify(VerifyInput{TransactionID: "tx", ProductID: "sku"}); err != nil {
		t.Fatalf("expected nil, got %v", err)
	}
}

func TestProductionVerifierRequiresPayload(t *testing.T) {
	v := ProductionVerifier{}
	err := v.Verify(VerifyInput{TransactionID: "tx", ProductID: "sku"})
	if err != ErrMissingPayload {
		t.Fatalf("expected ErrMissingPayload, got %v", err)
	}
}

func TestValidatePayloadChecksClientDataHash(t *testing.T) {
	hash := ClientDataHash("tx-1", "credits_100")
	payload := &Payload{
		KeyID:          "key-1",
		Assertion:      base64.StdEncoding.EncodeToString(make([]byte, 64)),
		ClientDataHash: base64.StdEncoding.EncodeToString(hash),
	}
	if err := validatePayload(VerifyInput{
		TransactionID: "tx-1",
		ProductID:     "credits_100",
		Payload:       payload,
	}); err != nil {
		t.Fatalf("expected valid payload, got %v", err)
	}
}

func TestValidatePayloadRejectsHashMismatch(t *testing.T) {
	payload := &Payload{
		KeyID:          "key-1",
		Assertion:      base64.StdEncoding.EncodeToString(make([]byte, 64)),
		ClientDataHash: base64.StdEncoding.EncodeToString(make([]byte, 32)),
	}
	err := validatePayload(VerifyInput{
		TransactionID: "tx-1",
		ProductID:     "credits_100",
		Payload:       payload,
	})
	if err != ErrClientDataHashMismatch {
		t.Fatalf("expected hash mismatch, got %v", err)
	}
}

func TestNewVerifierModes(t *testing.T) {
	if _, ok := NewVerifier(false, false).(DisabledVerifier); !ok {
		t.Fatal("expected disabled verifier")
	}
	if _, ok := NewVerifier(true, true).(MockVerifier); !ok {
		t.Fatal("expected mock verifier")
	}
	if _, ok := NewVerifier(true, false).(ProductionVerifier); !ok {
		t.Fatal("expected production verifier")
	}
}
