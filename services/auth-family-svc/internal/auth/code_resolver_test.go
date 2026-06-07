package auth

import "testing"

func TestCodeResolverMockFixedCode(t *testing.T) {
	resolver, err := NewCodeResolver("mock", "123456", "")
	if err != nil {
		t.Fatal(err)
	}

	code, err := resolver.Resolve("13900001111")
	if err != nil {
		t.Fatal(err)
	}
	if code != "123456" {
		t.Fatalf("code = %q, want 123456", code)
	}
}

func TestCodeResolverAliyunWhitelistOnly(t *testing.T) {
	raw := "13800138001:123456,13800138002:654321"
	resolver, err := NewCodeResolver("aliyun", "123456", raw)
	if err != nil {
		t.Fatal(err)
	}

	code, err := resolver.Resolve("13800138001")
	if err != nil || code != "123456" {
		t.Fatalf("whitelist admin: code=%q err=%v", code, err)
	}

	code, err = resolver.Resolve("13800138002")
	if err != nil || code != "654321" {
		t.Fatalf("whitelist member: code=%q err=%v", code, err)
	}

	code, err = resolver.Resolve("13900009999")
	if err != nil {
		t.Fatal(err)
	}
	if code == "123456" || code == "654321" {
		t.Fatalf("non-whitelist should be random, got fixed %q", code)
	}
	if len(code) != 6 {
		t.Fatalf("code length = %d", len(code))
	}
}

func TestParseSMSTestPhonesInvalid(t *testing.T) {
	if _, err := ParseSMSTestPhones("bad-entry"); err == nil {
		t.Fatal("expected parse error")
	}
	if _, err := ParseSMSTestPhones("13800138001:12"); err == nil {
		t.Fatal("expected short code error")
	}
}

func TestCodeResolverInvalidProvider(t *testing.T) {
	if _, err := NewCodeResolver("twilio", "", ""); err == nil {
		t.Fatal("expected provider error")
	}
}
