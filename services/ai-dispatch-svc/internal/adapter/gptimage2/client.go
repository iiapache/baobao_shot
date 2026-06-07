package gptimage2

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

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const (
	defaultModelID       = "gpt-image-1"
	defaultBaseURL       = "https://api.openai.com/v1"
	noTrainingHeader     = "OpenAI-Data-Collection-Opt-Out"
	noTrainingValue      = "true"
	generationsPath      = "/images/generations"
	editsPath            = "/images/edits"
)

// Client performs GPT Image generation and editing against OpenAI (via overseas proxy).
type Client interface {
	Generate(ctx context.Context, req VendorRequest) (string, error)
	Edit(ctx context.Context, req VendorRequest) (string, error)
}

// Config holds GptImage2 adapter runtime settings.
type Config struct {
	MockMode         bool
	APIKey           string
	OrgID            string
	BaseURL          string // overseas proxy base URL
	ModelID          string
	ObjectURLPrefix  string
	NoTrainingOptOut bool // OPENAI_NO_TRAINING_HEADER=1 (T7.4)
	HTTPClient       *http.Client
}

func (c Config) modelID() string {
	if strings.TrimSpace(c.ModelID) != "" {
		return c.ModelID
	}
	return defaultModelID
}

func (c Config) baseURL() string {
	if strings.TrimSpace(c.BaseURL) != "" {
		return strings.TrimRight(c.BaseURL, "/")
	}
	return defaultBaseURL
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
		APIKey:           c.APIKey,
		OrgID:            c.OrgID,
		BaseURL:          c.baseURL(),
		ModelID:          c.modelID(),
		NoTrainingOptOut: c.NoTrainingOptOut,
		HTTP:             httpClient,
	}
}

func (c Config) objectURL(objectKey string) string {
	prefix := strings.TrimRight(c.ObjectURLPrefix, "/")
	if prefix == "" {
		prefix = "https://s3-mock.example.com"
	}
	return prefix + "/" + strings.TrimPrefix(objectKey, "/")
}

type generationRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
	Size   string `json:"size"`
	N      int    `json:"n"`
}

type editRequest struct {
	Model    string `json:"model"`
	Prompt   string `json:"prompt"`
	ImageURL string `json:"image_url"`
	Size     string `json:"size"`
	N        int    `json:"n"`
}

type openAIImageResponse struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error"`
	Data []struct {
		URL string `json:"url"`
	} `json:"data"`
}

// HTTPClient calls the live OpenAI API or overseas proxy.
type HTTPClient struct {
	APIKey           string
	OrgID            string
	BaseURL          string
	ModelID          string
	NoTrainingOptOut bool
	HTTP             *http.Client
}

var errLiveClientStub = errors.New("gptimage2 live client requires OPENAI_API_KEY")

func (c *HTTPClient) setHeaders(req *http.Request) {
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	if strings.TrimSpace(c.OrgID) != "" {
		req.Header.Set("OpenAI-Organization", c.OrgID)
	}
	if c.NoTrainingOptOut {
		req.Header.Set(noTrainingHeader, noTrainingValue)
	}
}

func (c *HTTPClient) parseResponse(raw []byte, status int) (string, error) {
	var parsed openAIImageResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", NormalizeHTTPStatus(status, "invalid vendor response")
	}
	if parsed.Error.Message != "" {
		code := parsed.Error.Code
		if code == "" {
			code = parsed.Error.Type
		}
		return "", NormalizeVendorError(code, status, parsed.Error.Message)
	}
	if len(parsed.Data) == 0 || parsed.Data[0].URL == "" {
		return "", NormalizeVendorError("EMPTY_OUTPUT", status, "empty data")
	}
	return parsed.Data[0].URL, nil
}

// Generate posts an image-gen request through the overseas proxy.
func (c *HTTPClient) Generate(ctx context.Context, req VendorRequest) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errLiveClientStub
	}

	body, err := json.Marshal(generationRequest{
		Model:  req.ModelID,
		Prompt: req.Prompt,
		Size:   req.OutputSize,
		N:      1,
	})
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	url := c.BaseURL + generationsPath
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	c.setHeaders(httpReq)

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}
	return c.parseResponse(raw, resp.StatusCode)
}

// Edit posts an image-edit request through the overseas proxy (JSON image_url for proxy fetch).
func (c *HTTPClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errLiveClientStub
	}

	body, err := json.Marshal(editRequest{
		Model:    req.ModelID,
		Prompt:   req.Prompt,
		ImageURL: req.ImageURL,
		Size:     req.OutputSize,
		N:        1,
	})
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	url := c.BaseURL + editsPath
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	c.setHeaders(httpReq)

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}
	return c.parseResponse(raw, resp.StatusCode)
}

// MockClient simulates GPT Image responses for tests and local dev.
type MockClient struct{}

func (m *MockClient) invoke(ctx context.Context, req VendorRequest) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}

	marker := strings.ToLower(req.ObjectKey + " " + req.Prompt)
	switch {
	case strings.Contains(marker, "vendor_rate_limit"):
		return "", NormalizeVendorError("rate_limit_exceeded", http.StatusTooManyRequests, "rate limit")
	case strings.Contains(marker, "vendor_upstream"):
		return "", NormalizeVendorError("server_error", http.StatusInternalServerError, "server error")
	case strings.Contains(marker, "vendor_timeout"):
		return "", NormalizeHTTPStatus(http.StatusGatewayTimeout, "gateway timeout")
	case strings.Contains(marker, "vendor_face"):
		return "", NormalizeVendorError("face_not_detected", http.StatusOK, "face not detected")
	case strings.Contains(marker, "vendor_policy"):
		return "", NormalizeVendorError("content_policy_violation", http.StatusOK, "content policy")
	case strings.Contains(marker, "vendor_invalid"):
		return "", NormalizeVendorError("invalid_request_error", http.StatusBadRequest, "invalid parameter")
	}

	prefix := "gen"
	if req.Capability == model.CapabilityImageEdit {
		prefix = "edit"
	}
	key := strings.TrimPrefix(req.ObjectKey, "ai-tmp/")
	if key == "" {
		key = req.Style
	}
	return fmt.Sprintf("https://mock.gptimage.local/%s/%s", prefix, key), nil
}

// Generate returns a deterministic mock image URL or injects vendor errors via markers.
func (m *MockClient) Generate(ctx context.Context, req VendorRequest) (string, error) {
	return m.invoke(ctx, req)
}

// Edit returns a deterministic mock image URL or injects vendor errors via markers.
func (m *MockClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	return m.invoke(ctx, req)
}
