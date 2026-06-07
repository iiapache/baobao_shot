package apns

import (
	"context"
	"fmt"
	"strings"
	"sync"
)

// Client routes pushes through per-region connection pools and an injectable Sender.
type Client struct {
	mu      sync.RWMutex
	pools   map[Region]*pool
	sender  Sender
	cleaner TokenCleaner
}

// Config configures the dual-region APNs client stub.
type Config struct {
	Sandbox bool
	Sender  Sender
	Cleaner TokenCleaner
}

// NewClient builds cn/os pools. Sender defaults to MockSender when nil.
func NewClient(cfg Config) (*Client, error) {
	sender := cfg.Sender
	if sender == nil {
		sender = NewMockSender()
	}

	pools := make(map[Region]*pool, 2)
	for _, region := range []Region{RegionCN, RegionOS} {
		p, err := newPool(region, cfg.Sandbox)
		if err != nil {
			return nil, err
		}
		pools[region] = p
	}

	return &Client{
		pools:   pools,
		sender:  sender,
		cleaner: cfg.Cleaner,
	}, nil
}

// Send delivers a push via the region pool. Invalid tokens trigger automatic cleanup.
func (c *Client) Send(ctx context.Context, region Region, payload PushPayload) (SendResult, error) {
	if c == nil {
		return SendResult{}, fmt.Errorf("apns client is nil")
	}

	pool, err := c.poolFor(region)
	if err != nil {
		return SendResult{}, err
	}
	if err := pool.ping(ctx); err != nil {
		return SendResult{}, err
	}

	result, err := c.sender.Send(ctx, pool.hostForSend(), payload)
	if err != nil {
		if errorsIsTokenInvalid(err, result) {
			_ = c.cleanupToken(ctx, payload.DeviceToken)
		}
		return result, err
	}
	if result.TokenInvalid {
		_ = c.cleanupToken(ctx, payload.DeviceToken)
		return result, ErrTokenInvalid
	}
	return result, nil
}

// PoolHost returns the APNs host for a region (for diagnostics).
func (c *Client) PoolHost(region Region) (string, error) {
	pool, err := c.poolFor(region)
	if err != nil {
		return "", err
	}
	return pool.hostForSend(), nil
}

// Regions returns configured pool regions.
func (c *Client) Regions() []Region {
	c.mu.RLock()
	defer c.mu.RUnlock()
	out := make([]Region, 0, len(c.pools))
	for r := range c.pools {
		out = append(out, r)
	}
	return out
}

func (c *Client) poolFor(region Region) (*pool, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	region = Region(strings.ToLower(string(region)))
	p, ok := c.pools[region]
	if !ok {
		return nil, ErrUnsupportedRegion
	}
	return p, nil
}

func (c *Client) cleanupToken(ctx context.Context, apnsToken string) error {
	if c.cleaner == nil || apnsToken == "" {
		return nil
	}
	_, err := c.cleaner.CleanupInvalidToken(ctx, apnsToken)
	return err
}

func errorsIsTokenInvalid(err error, result SendResult) bool {
	return result.TokenInvalid || err == ErrTokenInvalid
}
