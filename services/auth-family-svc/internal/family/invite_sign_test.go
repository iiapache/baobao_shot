package family

import (
	"testing"
)

func TestSignAndVerifyInvitePayload(t *testing.T) {
	payload := SignInvitePayload("baobao://invite", "123456", "secret-key")
	if payload.Scheme != "baobao://invite" || payload.Code != "123456" || payload.Sig == "" {
		t.Fatalf("payload = %+v", payload)
	}
	if !VerifyInvitePayload(payload, "secret-key") {
		t.Fatal("expected valid signature")
	}
	if VerifyInvitePayload(payload, "wrong-key") {
		t.Fatal("expected invalid signature with wrong key")
	}
}

func TestGenerateInviteCode(t *testing.T) {
	code, err := GenerateInviteCode()
	if err != nil {
		t.Fatal(err)
	}
	if len(code) != InviteCodeLength {
		t.Fatalf("len = %d, want %d", len(code), InviteCodeLength)
	}
	for _, ch := range code {
		if ch < '0' || ch > '9' {
			t.Fatalf("non-digit in code %q", code)
		}
	}
}
