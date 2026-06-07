package auth

import (
	"fmt"
	"strings"
)

// CodeResolver picks verification codes for mock vs aliyun SMS modes.
type CodeResolver struct {
	provider  string
	fixedCode string
	whitelist map[string]string
}

// NewCodeResolver builds a resolver from SMS provider settings.
// mock: MOCK_SMS_FIXED_CODE applies to all CN phones when set.
// aliyun: only SMS_TEST_PHONES whitelist entries get fixed codes.
func NewCodeResolver(provider, mockFixedCode, testPhonesRaw string) (*CodeResolver, error) {
	provider = strings.ToLower(strings.TrimSpace(provider))
	if provider == "" {
		provider = "mock"
	}
	if provider != "mock" && provider != "aliyun" {
		return nil, fmt.Errorf("SMS_PROVIDER: unsupported provider %q", provider)
	}

	whitelist, err := ParseSMSTestPhones(testPhonesRaw)
	if err != nil {
		return nil, err
	}

	fixed := strings.TrimSpace(mockFixedCode)
	if fixed != "" && len(fixed) != codeDigits {
		return nil, fmt.Errorf("MOCK_SMS_FIXED_CODE: must be %d digits, got %d", codeDigits, len(fixed))
	}

	return &CodeResolver{
		provider:  provider,
		fixedCode: fixed,
		whitelist: whitelist,
	}, nil
}

// Provider returns the configured SMS provider name.
func (r *CodeResolver) Provider() string {
	if r == nil {
		return "mock"
	}
	return r.provider
}

// Whitelist returns phone→code mappings for test numbers.
func (r *CodeResolver) Whitelist() map[string]string {
	if r == nil {
		return nil
	}
	out := make(map[string]string, len(r.whitelist))
	for phone, code := range r.whitelist {
		out[phone] = code
	}
	return out
}

// IsWhitelisted reports whether phone has a configured fixed code.
func (r *CodeResolver) IsWhitelisted(phone string) bool {
	if r == nil {
		return false
	}
	_, ok := r.whitelist[phone]
	return ok
}

// Resolve returns the verification code for phone.
func (r *CodeResolver) Resolve(phone string) (string, error) {
	if r == nil {
		return generateNumericCode(codeDigits)
	}
	if code, ok := r.whitelist[phone]; ok {
		if len(code) != codeDigits {
			return "", fmt.Errorf("SMS_TEST_PHONES: code for %s must be %d digits", maskPhone(phone), codeDigits)
		}
		return code, nil
	}
	if r.provider == "mock" && len(r.fixedCode) == codeDigits {
		return r.fixedCode, nil
	}
	return generateNumericCode(codeDigits)
}

// ParseSMSTestPhones parses "phone:code,phone:code" whitelist entries.
func ParseSMSTestPhones(raw string) (map[string]string, error) {
	out := make(map[string]string)
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return out, nil
	}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		phone, code, ok := strings.Cut(part, ":")
		if !ok {
			return nil, fmt.Errorf("SMS_TEST_PHONES: invalid entry %q, want phone:code", part)
		}
		phone = strings.TrimSpace(phone)
		code = strings.TrimSpace(code)
		if !ValidateCNPhone(phone) {
			return nil, fmt.Errorf("SMS_TEST_PHONES: invalid phone %q", phone)
		}
		if len(code) != codeDigits {
			return nil, fmt.Errorf("SMS_TEST_PHONES: code for %s must be %d digits", maskPhone(phone), codeDigits)
		}
		out[phone] = code
	}
	return out, nil
}
