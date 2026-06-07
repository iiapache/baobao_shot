package apns

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/net/http2"
)

const apnsProviderTokenTTL = 50 * time.Minute

// HTTP2Config configures the live APNs HTTP/2 sender.
type HTTP2Config struct {
	KeyID          string
	TeamID         string
	PrivateKeyPEM  string
	DefaultTopic   string
	RequestTimeout time.Duration
}

// HTTP2Sender delivers pushes to Apple via HTTP/2 + JWT provider token.
type HTTP2Sender struct {
	keyID         string
	teamID        string
	privateKey    *ecdsa.PrivateKey
	defaultTopic  string
	client        *http.Client
	tokenMu       sync.Mutex
	cachedToken   string
	tokenIssuedAt time.Time
}

// NewHTTP2Sender validates credentials and prepares an HTTP/2 client.
func NewHTTP2Sender(cfg HTTP2Config) (*HTTP2Sender, error) {
	keyID := strings.TrimSpace(cfg.KeyID)
	teamID := strings.TrimSpace(cfg.TeamID)
	privateKeyPEM := strings.TrimSpace(cfg.PrivateKeyPEM)
	if keyID == "" || teamID == "" || privateKeyPEM == "" {
		return nil, fmt.Errorf("APNS_KEY_ID, APNS_TEAM_ID and APNS_PRIVATE_KEY_PEM are required when APNS_MOCK=false")
	}

	privateKey, err := parseECPrivateKey(privateKeyPEM)
	if err != nil {
		return nil, fmt.Errorf("parse APNS private key: %w", err)
	}

	timeout := cfg.RequestTimeout
	if timeout <= 0 {
		timeout = 10 * time.Second
	}

	transport := &http.Transport{}
	if err := http2.ConfigureTransport(transport); err != nil {
		return nil, fmt.Errorf("configure http2 transport: %w", err)
	}

	return &HTTP2Sender{
		keyID:        keyID,
		teamID:       teamID,
		privateKey:   privateKey,
		defaultTopic: strings.TrimSpace(cfg.DefaultTopic),
		client: &http.Client{
			Timeout:   timeout,
			Transport: transport,
		},
	}, nil
}

// Send implements Sender.
func (s *HTTP2Sender) Send(ctx context.Context, host string, payload PushPayload) (SendResult, error) {
	if s == nil {
		return SendResult{}, fmt.Errorf("http2 sender is nil")
	}

	body, err := MarshalPayload(payload)
	if err != nil {
		return SendResult{StatusCode: 400}, err
	}

	token, err := s.providerToken(ctx)
	if err != nil {
		return SendResult{}, err
	}

	topic := strings.TrimSpace(payload.Topic)
	if topic == "" {
		topic = s.defaultTopic
	}
	if topic == "" {
		return SendResult{}, fmt.Errorf("apns topic required")
	}

	url := fmt.Sprintf("https://%s/3/device/%s", strings.TrimSpace(host), strings.TrimSpace(payload.DeviceToken))
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return SendResult{}, err
	}

	req.Header.Set("authorization", "bearer "+token)
	req.Header.Set("apns-topic", topic)
	req.Header.Set("apns-push-type", PushType(payload))
	req.Header.Set("apns-priority", PriorityHeader(payload))
	req.Header.Set("content-type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return SendResult{}, err
	}
	defer resp.Body.Close()

	result := SendResult{
		APNSID:     strings.TrimSpace(resp.Header.Get("apns-id")),
		StatusCode: resp.StatusCode,
	}

	if resp.StatusCode == http.StatusOK {
		return result, nil
	}

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	reason := strings.TrimSpace(resp.Header.Get("apns-reason"))
	if reason == "" && len(respBody) > 0 {
		reason = strings.TrimSpace(string(respBody))
	}

	switch resp.StatusCode {
	case http.StatusGone, http.StatusBadRequest:
		if reason == "BadDeviceToken" || reason == "Unregistered" || reason == "DeviceTokenNotForTopic" {
			result.TokenInvalid = true
			return result, ErrTokenInvalid
		}
	}

	if reason != "" {
		return result, fmt.Errorf("apns send failed: status=%d reason=%s", resp.StatusCode, reason)
	}
	return result, fmt.Errorf("apns send failed: status=%d", resp.StatusCode)
}

func (s *HTTP2Sender) providerToken(_ context.Context) (string, error) {
	s.tokenMu.Lock()
	defer s.tokenMu.Unlock()

	if s.cachedToken != "" && time.Since(s.tokenIssuedAt) < apnsProviderTokenTTL {
		return s.cachedToken, nil
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"iss": s.teamID,
		"iat": now.Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = s.keyID

	signed, err := token.SignedString(s.privateKey)
	if err != nil {
		return "", fmt.Errorf("sign apns provider token: %w", err)
	}

	s.cachedToken = signed
	s.tokenIssuedAt = now
	return signed, nil
}

func parseECPrivateKey(pemText string) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(pemText))
	if block == nil {
		return nil, fmt.Errorf("invalid PEM block")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		key, err = x509.ParseECPrivateKey(block.Bytes)
		if err != nil {
			return nil, err
		}
	}

	ecKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("expected ECDSA private key")
	}
	return ecKey, nil
}
