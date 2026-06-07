package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"
)

const (
	appleJWKSURL             = "https://appleid.apple.com/auth/keys"
	appleJWKSRefreshInterval = 24 * time.Hour
)

type appleJWKSResponse struct {
	Keys []appleJWK `json:"keys"`
}

type appleJWK struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

// AppleJWKSProvider resolves Apple identity token signing keys by kid.
type AppleJWKSProvider interface {
	PublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error)
}

// AppleJWKSClient fetches and caches Apple JWKS for RS256 verification.
type AppleJWKSClient struct {
	httpClient *http.Client
	jwksURL    string

	mu          sync.RWMutex
	keys        map[string]*rsa.PublicKey
	lastFetched time.Time
}

// NewAppleJWKSClient creates a JWKS client for production Apple token verification.
func NewAppleJWKSClient(httpClient *http.Client) *AppleJWKSClient {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	return &AppleJWKSClient{
		httpClient: httpClient,
		jwksURL:    appleJWKSURL,
		keys:       make(map[string]*rsa.PublicKey),
	}
}

// PublicKey returns the RSA public key for the given key id.
func (c *AppleJWKSClient) PublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	if kid == "" {
		return nil, errors.New("missing kid in token header")
	}

	c.mu.RLock()
	key, ok := c.keys[kid]
	stale := time.Since(c.lastFetched) >= appleJWKSRefreshInterval
	c.mu.RUnlock()
	if ok && !stale {
		return key, nil
	}

	if err := c.refresh(ctx); err != nil {
		if ok {
			return key, nil
		}
		return nil, err
	}

	c.mu.RLock()
	defer c.mu.RUnlock()
	key, ok = c.keys[kid]
	if !ok {
		return nil, fmt.Errorf("apple jwks: key %q not found", kid)
	}
	return key, nil
}

func (c *AppleJWKSClient) refresh(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.jwksURL, nil)
	if err != nil {
		return fmt.Errorf("apple jwks request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("apple jwks fetch: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("apple jwks fetch: status %d", resp.StatusCode)
	}

	var payload appleJWKSResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return fmt.Errorf("apple jwks decode: %w", err)
	}

	keys := make(map[string]*rsa.PublicKey, len(payload.Keys))
	for _, jwk := range payload.Keys {
		if jwk.Kty != "RSA" || jwk.Kid == "" {
			continue
		}
		pub, err := rsaPublicKeyFromJWK(jwk)
		if err != nil {
			continue
		}
		keys[jwk.Kid] = pub
	}
	if len(keys) == 0 {
		return errors.New("apple jwks: no usable RSA keys")
	}

	c.mu.Lock()
	c.keys = keys
	c.lastFetched = time.Now()
	c.mu.Unlock()
	return nil
}

func rsaPublicKeyFromJWK(jwk appleJWK) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
	if err != nil {
		return nil, fmt.Errorf("decode n: %w", err)
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
	if err != nil {
		return nil, fmt.Errorf("decode e: %w", err)
	}

	n := new(big.Int).SetBytes(nBytes)
	e := new(big.Int).SetBytes(eBytes).Int64()
	if e <= 0 || e > int64(^uint(0)>>1) {
		return nil, errors.New("invalid rsa exponent")
	}

	return &rsa.PublicKey{N: n, E: int(e)}, nil
}
