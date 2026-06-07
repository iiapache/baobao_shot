package tongyi

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
	defaultEndpoint   = "https://dashscope.aliyuncs.com"
	imageSynthPath    = "/api/v1/services/aigc/image2image/image-synthesis"
	taskPathPrefix    = "/api/v1/tasks/"
	defaultModelID    = "wan2.5-i2i-preview"
	pollInterval      = 2 * time.Second
	maxPollAttempts   = 28
)

// Client performs Wanxiang image editing against DashScope API.
type Client interface {
	Edit(ctx context.Context, req VendorRequest) (string, error)
}

// Config holds Tongyi Wanxiang adapter runtime settings.
type Config struct {
	MockMode        bool
	APIKey          string
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
		APIKey:   c.APIKey,
		Endpoint: c.endpoint(),
		HTTP:     httpClient,
	}
}

func (c Config) objectURL(objectKey string) string {
	prefix := strings.TrimRight(c.ObjectURLPrefix, "/")
	if prefix == "" {
		prefix = "https://oss-mock.example.com"
	}
	return prefix + "/" + strings.TrimPrefix(objectKey, "/")
}

type wan25Request struct {
	Model      string `json:"model"`
	Input      wan25Input `json:"input"`
	Parameters wan25Params `json:"parameters"`
}

type wan25Input struct {
	Prompt string   `json:"prompt"`
	Images []string `json:"images"`
}

type wan25Params struct {
	N int `json:"n"`
}

type wanx21Request struct {
	Model      string `json:"model"`
	Input      wanx21Input `json:"input"`
	Parameters wan25Params `json:"parameters"`
}

type wanx21Input struct {
	Function     string `json:"function"`
	Prompt       string `json:"prompt"`
	BaseImageURL string `json:"base_image_url"`
}

type createTaskResponse struct {
	Output struct {
		TaskID     string `json:"task_id"`
		TaskStatus string `json:"task_status"`
		Results    []struct {
			URL string `json:"url"`
		} `json:"results"`
	} `json:"output"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

// HTTPClient calls the live DashScope Wanxiang API (async task + poll).
type HTTPClient struct {
	APIKey   string
	Endpoint string
	HTTP     *http.Client
}

var errLiveClientStub = errors.New("tongyi wanxiang live client requires DASHSCOPE_API_KEY")

// Edit submits an async image-edit task and polls until completion.
func (c *HTTPClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return "", errLiveClientStub
	}

	body, err := marshalRequest(req)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	taskID, err := c.submitTask(ctx, body)
	if err != nil {
		return "", err
	}
	return c.pollTask(ctx, taskID)
}

func marshalRequest(req VendorRequest) ([]byte, error) {
	if req.Function != "" {
		return json.Marshal(wanx21Request{
			Model: req.ModelID,
			Input: wanx21Input{
				Function:     req.Function,
				Prompt:       req.Prompt,
				BaseImageURL: req.ImageURL,
			},
			Parameters: wan25Params{N: 1},
		})
	}
	return json.Marshal(wan25Request{
		Model: req.ModelID,
		Input: wan25Input{
			Prompt: req.Prompt,
			Images: []string{req.ImageURL},
		},
		Parameters: wan25Params{N: 1},
	})
}

func (c *HTTPClient) submitTask(ctx context.Context, body []byte) (string, error) {
	url := c.Endpoint + imageSynthPath
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)
	httpReq.Header.Set("X-DashScope-Async", "enable")

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}

	var parsed createTaskResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", NormalizeHTTPStatus(resp.StatusCode, "invalid vendor response")
	}
	if parsed.Code != "" && parsed.Code != "null" {
		return "", NormalizeVendorError(parsed.Code, resp.StatusCode, parsed.Message)
	}
	if parsed.Output.TaskID == "" {
		return "", NormalizeVendorError("EMPTY_TASK", resp.StatusCode, "missing task_id")
	}
	return parsed.Output.TaskID, nil
}

func (c *HTTPClient) pollTask(ctx context.Context, taskID string) (string, error) {
	url := c.Endpoint + taskPathPrefix + taskID
	for attempt := 0; attempt < maxPollAttempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return "", NormalizeHTTPStatus(0, err.Error())
		}

		httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return "", NormalizeHTTPStatus(0, err.Error())
		}
		httpReq.Header.Set("Authorization", "Bearer "+c.APIKey)

		resp, err := c.HTTP.Do(httpReq)
		if err != nil {
			return "", NormalizeHTTPStatus(0, err.Error())
		}

		raw, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			return "", NormalizeHTTPStatus(resp.StatusCode, readErr.Error())
		}

		var parsed createTaskResponse
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return "", NormalizeHTTPStatus(resp.StatusCode, "invalid poll response")
		}
		if parsed.Code != "" && parsed.Code != "null" && parsed.Output.TaskStatus == "" {
			return "", NormalizeVendorError(parsed.Code, resp.StatusCode, parsed.Message)
		}

		switch strings.ToUpper(parsed.Output.TaskStatus) {
		case "SUCCEEDED":
			if len(parsed.Output.Results) == 0 || parsed.Output.Results[0].URL == "" {
				return "", NormalizeVendorError("EMPTY_OUTPUT", resp.StatusCode, "empty results")
			}
			return parsed.Output.Results[0].URL, nil
		case "FAILED", "CANCELED", "UNKNOWN":
			msg := parsed.Message
			if msg == "" {
				msg = "task " + strings.ToLower(parsed.Output.TaskStatus)
			}
			return "", NormalizeVendorError(parsed.Code, resp.StatusCode, msg)
		}

		select {
		case <-ctx.Done():
			return "", NormalizeHTTPStatus(0, ctx.Err().Error())
		case <-time.After(pollInterval):
		}
	}
	return "", NormalizeVendorError("RequestTimeout", http.StatusGatewayTimeout, "poll timeout")
}

// MockClient simulates Wanxiang responses for tests and local dev.
type MockClient struct{}

// Edit returns a deterministic mock image URL or injects vendor errors via markers.
func (m *MockClient) Edit(ctx context.Context, req VendorRequest) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", NormalizeHTTPStatus(0, err.Error())
	}

	marker := strings.ToLower(req.ObjectKey + " " + req.Prompt)
	switch {
	case strings.Contains(marker, "vendor_rate_limit"):
		return "", NormalizeVendorError("Throttling", http.StatusTooManyRequests, "qps limit")
	case strings.Contains(marker, "vendor_upstream"):
		return "", NormalizeVendorError("InternalError", http.StatusInternalServerError, "internal error")
	case strings.Contains(marker, "vendor_timeout"):
		return "", NormalizeHTTPStatus(http.StatusGatewayTimeout, "gateway timeout")
	case strings.Contains(marker, "vendor_face"):
		return "", NormalizeVendorError("FaceNotDetected", http.StatusOK, "face not detected")
	case strings.Contains(marker, "vendor_policy"):
		return "", NormalizeVendorError("DataInspectionFailed", http.StatusOK, "content policy")
	case strings.Contains(marker, "vendor_invalid"):
		return "", NormalizeVendorError("InvalidParameter", http.StatusBadRequest, "invalid parameter")
	}

	return "https://mock.wanxiang.local/out/" + strings.TrimPrefix(req.ObjectKey, "ai-tmp/"), nil
}
