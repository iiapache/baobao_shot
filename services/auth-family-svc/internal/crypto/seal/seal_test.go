package seal

import (
	"testing"
)

func TestSealUnsealRoundTrip(t *testing.T) {
	s, err := New(DeriveKeyFromSecret("test-secret"))
	if err != nil {
		t.Fatalf("new sealer: %v", err)
	}

	plain := "baidu-access-token-xyz"
	sealed, err := s.Seal(plain)
	if err != nil {
		t.Fatalf("seal: %v", err)
	}
	if sealed == plain || !IsSealed(sealed) {
		t.Fatalf("expected sealed ciphertext, got %q", sealed)
	}

	got, err := s.Unseal(sealed)
	if err != nil {
		t.Fatalf("unseal: %v", err)
	}
	if got != plain {
		t.Fatalf("unseal = %q, want %q", got, plain)
	}
}

func TestSealEmpty(t *testing.T) {
	s, _ := New(DeriveKeyFromSecret("test-secret"))
	sealed, err := s.Seal("")
	if err != nil || sealed != "" {
		t.Fatalf("empty seal = %q err=%v", sealed, err)
	}
	got, err := s.Unseal("")
	if err != nil || got != "" {
		t.Fatalf("empty unseal = %q err=%v", got, err)
	}
}

func TestUnsealInvalid(t *testing.T) {
	s, _ := New(DeriveKeyFromSecret("test-secret"))
	if _, err := s.Unseal("not-sealed"); err != ErrInvalidCiphertext {
		t.Fatalf("err = %v, want ErrInvalidCiphertext", err)
	}
}

func TestDifferentKeysCannotDecrypt(t *testing.T) {
	a, _ := New(DeriveKeyFromSecret("key-a"))
	b, _ := New(DeriveKeyFromSecret("key-b"))
	sealed, _ := a.Seal("secret")
	if _, err := b.Unseal(sealed); err != ErrInvalidCiphertext {
		t.Fatalf("cross-key decrypt should fail, err=%v", err)
	}
}
