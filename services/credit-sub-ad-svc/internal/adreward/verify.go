package adreward

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
)

const (
	NetworkPangle = "pangle"
	NetworkGDT    = "gdt"
	NetworkAdMob  = "admob"
)

// Verifier validates alliance server callback signatures.
type Verifier interface {
	Network() string
	Verify(transID, userID, sign string) bool
}

// HMACVerifier checks HMAC-SHA256 hex signatures used by mock/staging networks.
type HMACVerifier struct {
	network string
	secret  string
}

// NewHMACVerifier creates a network-specific HMAC verifier.
func NewHMACVerifier(network, secret string) *HMACVerifier {
	return &HMACVerifier{network: network, secret: secret}
}

func (v *HMACVerifier) Network() string {
	return v.network
}

func (v *HMACVerifier) Verify(transID, userID, sign string) bool {
	if v == nil || strings.TrimSpace(v.secret) == "" {
		return false
	}
	expected := ComputeHMACSign(v.secret, transID, userID)
	return hmac.Equal([]byte(strings.ToLower(sign)), []byte(expected))
}

// ComputeHMACSign derives the mock alliance callback signature.
func ComputeHMACSign(secret, transID, userID string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(fmt.Sprintf("%s:%s", transID, userID)))
	return hex.EncodeToString(mac.Sum(nil))
}

// Registry maps ad network names to verifiers.
type Registry struct {
	byNetwork map[string]Verifier
}

// NewRegistry builds a verifier registry from configured secrets.
func NewRegistry(pangleSecret, gdtSecret string) *Registry {
	registry := &Registry{byNetwork: make(map[string]Verifier)}
	if secret := strings.TrimSpace(pangleSecret); secret != "" {
		registry.byNetwork[NetworkPangle] = NewHMACVerifier(NetworkPangle, secret)
	}
	if secret := strings.TrimSpace(gdtSecret); secret != "" {
		registry.byNetwork[NetworkGDT] = NewHMACVerifier(NetworkGDT, secret)
	}
	// AdMob SSV uses Google public keys; staging mock reuses HMAC when secret is set.
	return registry
}

// Register adds or replaces a verifier.
func (r *Registry) Register(v Verifier) {
	if r == nil || v == nil {
		return
	}
	if r.byNetwork == nil {
		r.byNetwork = make(map[string]Verifier)
	}
	r.byNetwork[strings.ToLower(v.Network())] = v
}

// Verify checks a callback signature for the given network.
func (r *Registry) Verify(network, transID, userID, sign string) bool {
	if r == nil {
		return false
	}
	verifier, ok := r.byNetwork[strings.ToLower(strings.TrimSpace(network))]
	if !ok {
		return false
	}
	return verifier.Verify(transID, userID, sign)
}
