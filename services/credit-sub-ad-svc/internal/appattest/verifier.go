package appattest

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
)

var (
	// ErrDisabled indicates App Attest verification is turned off.
	ErrDisabled = errors.New("app attest disabled")
	// ErrMissingPayload indicates required appAttest fields are absent.
	ErrMissingPayload = errors.New("app attest payload required")
	// ErrInvalidPayload indicates malformed appAttest fields.
	ErrInvalidPayload = errors.New("invalid app attest payload")
	// ErrClientDataHashMismatch indicates clientDataHash does not match the request.
	ErrClientDataHashMismatch = errors.New("app attest client data hash mismatch")
)

// Payload is the optional App Attest attachment on IAP verify requests.
type Payload struct {
	KeyID           string
	Assertion       string
	ClientDataHash  string
}

// VerifyInput binds the IAP transaction context to an optional attestation payload.
type VerifyInput struct {
	TransactionID string
	ProductID     string
	Payload       *Payload
}

// Verifier validates App Attest assertions attached to sensitive requests.
type Verifier interface {
	Enabled() bool
	Verify(in VerifyInput) error
}

// DisabledVerifier skips App Attest checks (Debug / Staging default).
type DisabledVerifier struct{}

func (DisabledVerifier) Enabled() bool { return false }

func (DisabledVerifier) Verify(_ VerifyInput) error { return nil }

// MockVerifier accepts missing payloads or structurally valid attachments (dev / Mock API).
type MockVerifier struct{}

func (MockVerifier) Enabled() bool { return true }

func (MockVerifier) Verify(in VerifyInput) error {
	if in.Payload == nil {
		return nil
	}
	return validatePayload(in)
}

// ProductionVerifier requires a valid attachment when App Attest is enabled.
type ProductionVerifier struct{}

func (ProductionVerifier) Enabled() bool { return true }

func (ProductionVerifier) Verify(in VerifyInput) error {
	if in.Payload == nil {
		return ErrMissingPayload
	}
	return validatePayload(in)
}

// NewVerifier selects the verifier implementation from service config.
func NewVerifier(enabled, mock bool) Verifier {
	if !enabled {
		return DisabledVerifier{}
	}
	if mock {
		return MockVerifier{}
	}
	return ProductionVerifier{}
}

func validatePayload(in VerifyInput) error {
	payload := in.Payload
	if payload == nil {
		return ErrMissingPayload
	}

	keyID := strings.TrimSpace(payload.KeyID)
	assertion := strings.TrimSpace(payload.Assertion)
	clientDataHash := strings.TrimSpace(payload.ClientDataHash)
	if keyID == "" || assertion == "" || clientDataHash == "" {
		return ErrInvalidPayload
	}

	assertionBytes, err := base64.StdEncoding.DecodeString(assertion)
	if err != nil || len(assertionBytes) < 32 {
		return ErrInvalidPayload
	}

	hashBytes, err := base64.StdEncoding.DecodeString(clientDataHash)
	if err != nil || len(hashBytes) != sha256.Size {
		return ErrInvalidPayload
	}

	expected := ClientDataHash(in.TransactionID, in.ProductID)
	if string(hashBytes) != string(expected) {
		return ErrClientDataHashMismatch
	}

	return nil
}

// ClientDataHash mirrors iOS AppAttestIAPAttachmentBuilder:
// SHA256("{transactionId}:{productId}").
func ClientDataHash(transactionID, productID string) []byte {
	challenge := fmt.Sprintf("%s:%s", strings.TrimSpace(transactionID), strings.TrimSpace(productID))
	sum := sha256.Sum256([]byte(challenge))
	return sum[:]
}
