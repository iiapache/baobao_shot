package nanobanana

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
	defaultModelID   = "imagen-3.0-capability-001"
	defaultLocation  = "us-central1"
	editImageAction  = ":editImage"
	noTrainingHeader = "X-Vertex-AI-Data-Usage"
	noTrainingValue  = "no-training"
)

// Client performs Nano Banana image editing against Google Vertex (via overseas GCP proxy).
type Client interface {
	Edit(ctx context.Context, req VendorRequest) (string, error)
}

// Config holds NanoBanana adapter runtime settings.
type Config struct {
	MockMode          bool
	APIKey            string
	ProjectID         string
	Location          string
	Endpoint          string // overseas GCP proxy base URL; empty builds Vertex default
	ModelID           string
	ObjectURLPrefix   string
	NoTrainingOptOut  bool // routes to non-training contract endpoint (T7.4)
	HTTPClient        *http.Client
}

func (c Config) modelID() string {
	if strings.TrimSpace(c.ModelID) != "" {
		return c.ModelID
	}
	return defaultModelID
}

func (c Config) location() string {
	if strings.TrimSpace(c.Location) != "" {
		return c.Location
	}
	return defaultLocation
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
		ProjectID:        c.ProjectID,
		Location:         c.location(),
		Endpoint:         strings.TrimRight(c.Endpoint, "/"),
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

func (c *HTTPClient) editURL() string {
	if c.Endpoint != "" {
		return c.Endpoint + "/v1/image-edit"
	}
	return fmt.Sprintf(
		"https://%s-aiplatform.googleapis.com/v1/projects/%s/locations/%s/publishers/google/models/%s%s",
		c.Location, c.ProjectID, c.Location, c.ModelID, editImageAction,
	)
}

type editImageRequest struct {
	Model     string `json:"model"`
	Prompt    string `json:"prompt"`
	ImageURL  string `json:"image_url"`
	SampleCount int  `json:"sample_count"`
}

type editImageResponse struct {
	Error struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error"`
	Predictions []struct {
		BytesBase64Encoded string `json:"bytesBase64Encoded"`
		MimeType           string `json:"mimeType"`
	} `json:"predictions"`
	Images []struct {
		URL string `json:"url"`
	} `json:"images"`
}

// HTTPClient calls the live Vertex / GCP proxy API.
type HTTPClient struct {
	APIKey           string
	ProjectID        string
	Location         string
	Endpoint         string
	ModelID          string
	NoTrainingOptOut bool
	HTTP             *http.Client
}

var errLiveClientStub = errors.New("nanobanana live client requires GOOGLE_API_KEY and GOOGLE_PROJECT_ID")

// Edit submits an image-edit request through the overseas GCP proxy.
func (c *HTTPClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" || strings.TrimSpace(c.ProjectID) == "" {
		return "", errLiveClientStub
	}

	body, err := json.Marshal(editImageRequest{
		Model:       req.ModelID,
		Prompt:      req.Prompt,
		ImageURL:    req.ImageURL,
		SampleCount: 1,
	})
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	url := c.editURL()
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)
	if c.NoTrainingOptOut {
		httpReq.Header.Set(noTrainingHeader, noTrainingValue)
	}

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}

	var parsed editImageResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, "invalid vendor response")
	}

	if parsed.Error.Status != "" || parsed.Error.Message != "" {
		status := parsed.Error.Status
		if status == "" {
			status = fmt.Sprintf("%d", parsed.Error.Code)
		}
		return "", NormalizeVendorError(status, resp.StatusCode, parsed.Error.Message)
	}

	for _, img := range parsed.Images {
		if img.URL != "" {
			return img.URL, nil
		}
	}
	if len(parsed.Predictions) > 0 && parsed.Predictions[0].BytesBase64Encoded != "" {
		return "data:" + parsed.Predictions[0].MimeType + ";base64," + parsed.Predictions[0].BytesBase64Encoded, nil
	}

	if resp.StatusCode >= 400 {
		return "", NormalizeHTTPStatus(resp.StatusCode, "vendor error")
	}
	return "", NormalizeVendorError("EMPTY_OUTPUT", resp.StatusCode, "empty image output")
}

// MockClient simulates Nano Banana responses for tests and local dev.
type MockClient struct{}

// Edit returns a deterministic mock image URL or injects vendor errors via markers.
func (m *MockClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}

	marker := strings.ToLower(req.ObjectKey + " " + req.Prompt)
	switch {
	case strings.Contains(marker, "vendor_rate_limit"):
		return "", NormalizeVendorError("RESOURCE_EXHAUSTED", http.StatusTooManyRequests, "quota exceeded")
	case strings.Contains(marker, "vendor_upstream"):
		return "", NormalizeVendorError("UNAVAILABLE", http.StatusInternalServerError, "upstream unavailable")
	case strings.Contains(marker, "vendor_timeout"):
		return "", NormalizeHTTPStatus(http.StatusGatewayTimeout, "gateway timeout")
	case strings.Contains(marker, "vendor_face"):
		return "", NormalizeVendorError("FACE_NOT_DETECTED", http.StatusOK, "face not detected")
	case strings.Contains(marker, "vendor_policy"):
		return "", NormalizeVendorError("SAFETY_FILTER", http.StatusOK, "safety filter")
	case strings.Contains(marker, "vendor_invalid"):
		return "", NormalizeVendorError("INVALID_ARGUMENT", http.StatusBadRequest, "invalid parameter")
	}

	return "https://mock.nanobanana.local/out/" + strings.TrimPrefix(req.ObjectKey, "ai-tmp/"), nil
}
