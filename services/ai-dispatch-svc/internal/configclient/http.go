package configclient

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// HTTPClient calls config-svc GET /v1/config/features.
type HTTPClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewHTTPClient creates a config-svc HTTP client.
func NewHTTPClient(baseURL string) *HTTPClient {
	return &HTTPClient{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 3 * time.Second,
		},
	}
}

type featuresAPIResponse struct {
	Code string `json:"code"`
	Data struct {
		Features map[string]FeatureResult `json:"features"`
	} `json:"data"`
}

// Features fetches evaluated feature flags from config-svc.
func (c *HTTPClient) Features(ctx context.Context, req Request) (map[string]FeatureResult, error) {
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/v1/config/features", nil)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("X-Region", req.Region)
	if req.AppVersion != "" {
		httpReq.Header.Set("X-App-Version", req.AppVersion)
	}
	httpReq.Header.Set("X-Device-Id", "ai-dispatch-svc")
	if req.UserID != "" {
		httpReq.Header.Set("Authorization", "Bearer dev:"+req.UserID)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("config-svc request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("config-svc status %d: %s", resp.StatusCode, string(body))
	}

	var parsed featuresAPIResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, fmt.Errorf("decode config-svc response: %w", err)
	}
	if parsed.Data.Features == nil {
		return map[string]FeatureResult{}, nil
	}
	return parsed.Data.Features, nil
}
