package jimeng

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	defaultEndpoint = "https://visual.volcengineapi.com"
	vendorAction    = "CVProcess"
	vendorVersion   = "2022-08-31"
	defaultModelID  = "jimeng-v3"
)

// Client performs Jimeng image editing against Volcengine Visual API.
type Client interface {
	Edit(ctx context.Context, req VendorRequest) (string, error)
}

// Config holds Jimeng adapter runtime settings.
type Config struct {
	MockMode        bool
	APIKey          string
	APISecret       string
	Endpoint        string
	ModelID         string
	ObjectURLPrefix string
	HTTPClient      *http.Client
}

func (c Config) endpoint() string {
	if strings.TrimSpace(c.Endpoint) != "" {
		return strings.TrimRight(c.Endpoint, "/")
	}
	return defaultEndpoint
}

func (c Config) modelID() string {
	if strings.TrimSpace(c.ModelID) != "" {
		return c.ModelID
	}
	return defaultModelID
}

func (c Config) client() Client {
	if c.MockMode {
		return &MockClient{}
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 55 * time.Second}
	}
	return &HTTPClient{
		APIKey:    c.APIKey,
		APISecret: c.APISecret,
		Endpoint:  c.endpoint(),
		HTTP:      httpClient,
	}
}

func (c Config) objectURL(objectKey string) string {
	prefix := strings.TrimRight(c.ObjectURLPrefix, "/")
	if prefix == "" {
		prefix = "https://oss-mock.example.com"
	}
	return prefix + "/" + strings.TrimPrefix(objectKey, "/")
}

type cvProcessRequest struct {
	ReqKey    string   `json:"req_key"`
	ModelID   string   `json:"model_id,omitempty"`
	ImageURLs []string `json:"image_urls"`
	Prompt    string   `json:"prompt"`
}

type cvProcessResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		ImageURLs []string `json:"image_urls"`
	} `json:"data"`
}

// HTTPClient calls the live Volcengine Visual API.
type HTTPClient struct {
	APIKey    string
	APISecret string
	Endpoint  string
	HTTP      *http.Client
}

var errLiveClientStub = errors.New("jimeng live client signing not implemented")

// Edit posts a CVProcess request (live signing deferred to infra wiring).
func (c *HTTPClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errLiveClientStub
	}

	body, err := json.Marshal(cvProcessRequest{
		ReqKey:    req.ReqKey,
		ModelID:   req.ModelID,
		ImageURLs: []string{req.ImageURL},
		Prompt:    req.Prompt,
	})
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	url := fmt.Sprintf("%s?Action=%s&Version=%s", c.Endpoint, vendorAction, vendorVersion)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}

	var parsed cvProcessResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, "invalid vendor response")
	}

	if parsed.Code != 10000 {
		return "", NormalizeVendorError(strconvCode(parsed.Code), resp.StatusCode, parsed.Message)
	}
	if len(parsed.Data.ImageURLs) == 0 {
		return "", NormalizeVendorError("EMPTY_OUTPUT", resp.StatusCode, "empty image_urls")
	}
	return parsed.Data.ImageURLs[0], nil
}

func strconvCode(code int) string {
	return fmt.Sprintf("%d", code)
}

// MockClient simulates Jimeng responses for tests and local dev.
type MockClient struct{}

// Edit returns a deterministic mock image URL or injects vendor errors via markers.
func (m *MockClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}

	marker := strings.ToLower(req.ObjectKey + " " + req.Prompt)
	switch {
	case strings.Contains(marker, "vendor_rate_limit"):
		return "", NormalizeVendorError("50411", http.StatusTooManyRequests, "qps limit")
	case strings.Contains(marker, "vendor_upstream"):
		return "", NormalizeVendorError("50500", http.StatusInternalServerError, "internal error")
	case strings.Contains(marker, "vendor_timeout"):
		return "", NormalizeHTTPStatus(http.StatusGatewayTimeout, "gateway timeout")
	case strings.Contains(marker, "vendor_face"):
		return "", NormalizeVendorError("60208", http.StatusOK, "face not detected")
	case strings.Contains(marker, "vendor_policy"):
		return "", NormalizeVendorError("40301", http.StatusOK, "content policy")
	case strings.Contains(marker, "vendor_invalid"):
		return "", NormalizeVendorError("40001", http.StatusBadRequest, "invalid parameter")
	}

	return "https://mock.jimeng.local/out/" + strings.TrimPrefix(req.ObjectKey, "ai-tmp/"), nil
}
