package appattest

import "testing"

func TestParsePayloadAbsent(t *testing.T) {
	payload, err := ParsePayload([]byte(`{"transactionId":"tx","productId":"sku","signedTransaction":"jws"}`))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if payload != nil {
		t.Fatal("expected nil payload")
	}
}

func TestParsePayloadPresent(t *testing.T) {
	raw := []byte(`{
		"transactionId":"tx",
		"productId":"sku",
		"signedTransaction":"jws",
		"appAttest":{"keyId":"kid","assertion":"abc","clientDataHash":"def"}
	}`)
	payload, err := ParsePayload(raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if payload == nil || payload.KeyID != "kid" {
		t.Fatalf("unexpected payload: %+v", payload)
	}
}
