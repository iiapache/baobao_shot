package aliyun

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type brokenClient struct {
	err error
}

func (b brokenClient) AuditText(context.Context, string, string) (bool, []string, error) {
	return false, nil, b.err
}

func (b brokenClient) AuditImage(context.Context, string, string) (bool, []string, error) {
	return false, nil, b.err
}

func (b brokenClient) AuditVideo(context.Context, string, string) (bool, []string, error) {
	return false, nil, b.err
}

// Client performs Aliyun Green content moderation RPCs.
type Client interface {
	AuditText(ctx context.Context, text, scenes string) (bool, []string, error)
	AuditImage(ctx context.Context, objectKey, scenes string) (bool, []string, error)
	AuditVideo(ctx context.Context, objectKey, scenes string) (bool, []string, error)
}

// HTTPClient calls Green scan endpoints over HTTP (mock-audit WireMock or signed upstream).
type HTTPClient struct {
	Endpoint        string
	ObjectURLPrefix string
	ImageScenes     string
	TextScenes      string
	HTTP            *http.Client
}

func (c *HTTPClient) httpClient() *http.Client {
	if c.HTTP != nil {
		return c.HTTP
	}
	return &http.Client{Timeout: 4 * time.Second}
}

func (c *HTTPClient) endpoint() string {
	if strings.TrimSpace(c.Endpoint) != "" {
		return strings.TrimRight(c.Endpoint, "/")
	}
	return "https://green.cn-shanghai.aliyuncs.com"
}

func (c *HTTPClient) AuditText(ctx context.Context, text, scenes string) (bool, []string, error) {
	if scenes == "" {
		scenes = c.TextScenes
	}
	body, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"content": text},
		},
	})
	if err != nil {
		return false, nil, err
	}
	return c.postScan(ctx, "/green/text/scan", body)
}

func (c *HTTPClient) AuditImage(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	if scenes == "" {
		scenes = c.ImageScenes
	}
	body, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"url": objectURL(c.ObjectURLPrefix, objectKey)},
		},
	})
	if err != nil {
		return false, nil, err
	}
	return c.postScan(ctx, "/green/image/scan", body)
}

func (c *HTTPClient) AuditVideo(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	if scenes == "" {
		scenes = c.ImageScenes
	}
	body, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"url": objectURL(c.ObjectURLPrefix, objectKey)},
		},
	})
	if err != nil {
		return false, nil, err
	}
	// mock-audit exposes /green/video/scan; live Green uses /green/video/syncscan via SDK.
	return c.postScan(ctx, "/green/video/scan", body)
}

func (c *HTTPClient) postScan(ctx context.Context, path string, body []byte) (bool, []string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint()+path, bytes.NewReader(body))
	if err != nil {
		return false, nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient().Do(req)
	if err != nil {
		return false, nil, fmt.Errorf("green http: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return false, nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return false, nil, fmt.Errorf("green http status %d: %s", resp.StatusCode, string(raw))
	}
	return parseScanResponse(raw)
}
