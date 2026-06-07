// Package seal provides AES-256-GCM encryption for sensitive token fields at rest.
package seal

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strings"
)

const prefix = "v1:"

// ErrInvalidCiphertext is returned when sealed data cannot be decrypted.
var ErrInvalidCiphertext = errors.New("invalid sealed ciphertext")

// Sealer encrypts and decrypts token strings using AES-256-GCM.
type Sealer struct {
	aead cipher.AEAD
}

// New creates a Sealer from a 32-byte key.
func New(key []byte) (*Sealer, error) {
	if len(key) != 32 {
		return nil, fmt.Errorf("seal key must be 32 bytes, got %d", len(key))
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	return &Sealer{aead: aead}, nil
}

// DeriveKeyFromSecret derives a 32-byte AES key from an arbitrary secret string.
func DeriveKeyFromSecret(secret string) []byte {
	sum := sha256.Sum256([]byte(secret))
	return sum[:]
}

// Seal encrypts plaintext. Empty strings are stored as empty without encryption.
func (s *Sealer) Seal(plaintext string) (string, error) {
	if plaintext == "" {
		return "", nil
	}
	nonce := make([]byte, s.aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("seal nonce: %w", err)
	}
	ciphertext := s.aead.Seal(nonce, nonce, []byte(plaintext), nil)
	return prefix + base64.RawStdEncoding.EncodeToString(ciphertext), nil
}

// Unseal decrypts a value produced by Seal.
func (s *Sealer) Unseal(sealed string) (string, error) {
	if sealed == "" {
		return "", nil
	}
	if !strings.HasPrefix(sealed, prefix) {
		return "", ErrInvalidCiphertext
	}
	raw, err := base64.RawStdEncoding.DecodeString(strings.TrimPrefix(sealed, prefix))
	if err != nil {
		return "", ErrInvalidCiphertext
	}
	nonceSize := s.aead.NonceSize()
	if len(raw) < nonceSize {
		return "", ErrInvalidCiphertext
	}
	plain, err := s.aead.Open(nil, raw[:nonceSize], raw[nonceSize:], nil)
	if err != nil {
		return "", ErrInvalidCiphertext
	}
	return string(plain), nil
}

// IsSealed reports whether value looks like an encrypted token payload.
func IsSealed(value string) bool {
	return strings.HasPrefix(value, prefix)
}
