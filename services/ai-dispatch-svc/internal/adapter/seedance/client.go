package seedance

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
	defaultEndpoint     = "https://visual.volcengineapi.com"
	submitAction        = "CVSync2AsyncSubmitTask"
	getResultAction     = "CVSync2AsyncGetResult"
	vendorVersion       = "2022-08-31"
	defaultPollInterval = 5 * time.Second
	videoInvokeTimeout  = 5 * time.Minute
)

// Client performs Seedance image-to-video generation via Volcengine async CV API.
type Client interface {
	Generate(ctx context.Context, req VendorRequest) (VideoResult, error)
}

// VideoResult is a validated vendor video artifact.
type VideoResult struct {
	URL    string
	Format string
	Codec  string
}

// Config holds Seedance adapter runtime settings.
type Config struct {
	MockMode        bool
	APIKey          string
	APISecret       string
	Endpoint        string
	ModelID         string
	ObjectURLPrefix string
	HTTPClient      *http.Client
	PollInterval    time.Duration
}

func (c Config) endpoint() string {
	if strings.TrimSpace(c.Endpoint) != "" {
		return strings.TrimRight(c.Endpoint, "/")
	}
	return defaultEndpoint
}

func (c Config) pollInterval() time.Duration {
	if c.PollInterval > 0 {
		return c.PollInterval
	}
	return defaultPollInterval
}

func (c Config) client() Client {
	if c.MockMode {
		return &MockClient{}
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 30 * time.Second}
	}
	return &HTTPClient{
		APIKey:       c.APIKey,
		APISecret:    c.APISecret,
		Endpoint:     c.endpoint(),
		HTTP:         httpClient,
		PollInterval: c.pollInterval(),
	}
}

func (c Config) objectURL(objectKey string) string {
	prefix := strings.TrimRight(c.ObjectURLPrefix, "/")
	if prefix == "" {
		prefix = "https://oss-mock.example.com"
	}
	return prefix + "/" + strings.TrimPrefix(objectKey, "/")
}

type submitRequest struct {
	ReqKey    string   `json:"req_key"`
	Prompt    string   `json:"prompt"`
	ImageURLs []string `json:"image_urls"`
	Frames    int      `json:"frames"`
	Seed      int      `json:"seed"`
	ReturnURL bool     `json:"return_url"`
	Format    string   `json:"format,omitempty"`
	Codec     string   `json:"codec,omitempty"`
}

type getResultRequest struct {
	ReqKey string `json:"req_key"`
	TaskID string `json:"task_id"`
}

type vendorEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

type submitData struct {
	TaskID string `json:"task_id"`
}

type resultData struct {
	Status   string          `json:"status"`
	VideoURL string          `json:"video_url"`
	RespData json.RawMessage `json:"resp_data"`
	Format   string          `json:"format"`
	Codec    string          `json:"codec"`
}

type respDataPayload struct {
	VideoURL string `json:"video_url"`
	Format   string `json:"format"`
	Codec    string `json:"codec"`
}

var errLiveClientStub = errors.New("seedance live client signing not implemented")

// HTTPClient calls the live Volcengine Visual async video API.
type HTTPClient struct {
	APIKey       string
	APISecret    string
	Endpoint     string
	HTTP         *http.Client
	PollInterval time.Duration
}

// Generate submits an async task and polls until completion or timeout (5min).
func (c *HTTPClient) Generate(ctx context.Context, req VendorRequest) (VideoResult, error) {
	if strings.TrimSpace(c.APIKey) == "" {
		return VideoResult{}, errLiveClientStub
	}

	ctx, cancel := context.WithTimeout(ctx, videoInvokeTimeout)
	defer cancel()

	taskID, err := c.submitTask(ctx, req)
	if err != nil {
		return VideoResult{}, err
	}

	ticker := time.NewTicker(c.PollInterval)
	defer ticker.Stop()

	for {
		result, done, err := c.getResult(ctx, req.ReqKey, taskID)
		if err != nil {
			return VideoResult{}, err
		}
		if done {
			return result, nil
		}

		select {
		case <-ctx.Done():
			return VideoResult{}, NormalizeHTTPStatus(0, "video generation timed out after 5 minutes")
		case <-ticker.C:
		}
	}
}

func (c *HTTPClient) submitTask(ctx context.Context, req VendorRequest) (string, error) {
	body, err := json.Marshal(submitRequest{
		ReqKey:    req.ReqKey,
		Prompt:    req.Prompt,
		ImageURLs: []string{req.ImageURL},
		Frames:    req.Frames,
		Seed:      -1,
		ReturnURL: true,
		Format:    req.Format,
		Codec:     req.Codec,
	})
	if err != nil {
		return "", fmt.Errorf("marshal submit request: %w", err)
	}

	var parsed vendorEnvelope
	if err := c.post(ctx, submitAction, body, &parsed); err != nil {
		return "", err
	}
	if parsed.Code != 10000 {
		return "", NormalizeVendorError(strconvCode(parsed.Code), http.StatusOK, parsed.Message)
	}

	var data submitData
	if err := json.Unmarshal(parsed.Data, &data); err != nil {
		return "", NormalizeVendorError("INVALID_SUBMIT", http.StatusOK, "invalid submit response")
	}
	if strings.TrimSpace(data.TaskID) == "" {
		return "", NormalizeVendorError("EMPTY_TASK_ID", http.StatusOK, "missing task_id")
	}
	return data.TaskID, nil
}

func (c *HTTPClient) getResult(ctx context.Context, reqKey, taskID string) (VideoResult, bool, error) {
	body, err := json.Marshal(getResultRequest{ReqKey: reqKey, TaskID: taskID})
	if err != nil {
		return VideoResult{}, false, fmt.Errorf("marshal result request: %w", err)
	}

	var parsed vendorEnvelope
	if err := c.post(ctx, getResultAction, body, &parsed); err != nil {
		return VideoResult{}, false, err
	}
	if parsed.Code != 10000 {
		return VideoResult{}, false, NormalizeVendorError(strconvCode(parsed.Code), http.StatusOK, parsed.Message)
	}

	var data resultData
	if err := json.Unmarshal(parsed.Data, &data); err != nil {
		return VideoResult{}, false, NormalizeVendorError("INVALID_RESULT", http.StatusOK, "invalid result response")
	}

	switch strings.ToLower(strings.TrimSpace(data.Status)) {
	case "in_queue", "generating", "processing", "running", "":
		return VideoResult{}, false, nil
	case "done", "success":
		result, err := parseVideoResult(data)
		if err != nil {
			return VideoResult{}, false, err
		}
		if err := validateVideoResult(result); err != nil {
			return VideoResult{}, false, err
		}
		return result, true, nil
	case "not_found", "expired":
		return VideoResult{}, false, NormalizeVendorError(data.Status, http.StatusOK, "video task "+data.Status)
	default:
		return VideoResult{}, false, NormalizeVendorError(data.Status, http.StatusOK, "unexpected task status")
	}
}

func (c *HTTPClient) post(ctx context.Context, action string, body []byte, out *vendorEnvelope) error {
	url := fmt.Sprintf("%s?Action=%s&Version=%s", c.Endpoint, action, vendorVersion)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return NormalizeHTTPStatus(0, err.Error())
	}
	httpReq.Header.Set("Content-Type", "application/json")
	// Volcengine request signing (HMAC) is wired in deployment; stub returns errLiveClientStub until then.

	resp, err := c.HTTP.Do(httpReq)
	if err != nil {
		return NormalizeHTTPStatus(0, err.Error())
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return NormalizeHTTPStatus(resp.StatusCode, err.Error())
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return NormalizeHTTPStatus(resp.StatusCode, "invalid vendor response")
	}
	return nil
}

func parseVideoResult(data resultData) (VideoResult, error) {
	result := VideoResult{
		URL:    strings.TrimSpace(data.VideoURL),
		Format: strings.ToLower(strings.TrimSpace(data.Format)),
		Codec:  strings.ToLower(strings.TrimSpace(data.Codec)),
	}

	if result.URL == "" && len(data.RespData) > 0 {
		var payload respDataPayload
		if err := json.Unmarshal(data.RespData, &payload); err == nil {
			result.URL = strings.TrimSpace(payload.VideoURL)
			if result.Format == "" {
				result.Format = strings.ToLower(strings.TrimSpace(payload.Format))
			}
			if result.Codec == "" {
				result.Codec = strings.ToLower(strings.TrimSpace(payload.Codec))
			}
		}
	}

	if result.URL == "" {
		return VideoResult{}, NormalizeVendorError("EMPTY_OUTPUT", http.StatusOK, "empty video_url")
	}
	if result.Format == "" {
		result.Format = outputFormatMP4
	}
	if result.Codec == "" {
		result.Codec = outputCodecH264
	}
	return result, nil
}

func validateVideoResult(result VideoResult) error {
	if result.Format != outputFormatMP4 {
		return NormalizeVendorError("INVALID_FORMAT", http.StatusOK, fmt.Sprintf("output format %q, want mp4", result.Format))
	}
	if result.Codec != outputCodecH264 {
		return NormalizeVendorError("INVALID_CODEC", http.StatusOK, fmt.Sprintf("output codec %q, want h264", result.Codec))
	}
	if !strings.Contains(strings.ToLower(result.URL), ".mp4") && !strings.Contains(strings.ToLower(result.URL), "mp4") {
		return NormalizeVendorError("INVALID_FORMAT", http.StatusOK, "video url does not indicate mp4 output")
	}
	return nil
}

func strconvCode(code int) string {
	return fmt.Sprintf("%d", code)
}

// MockClient simulates Seedance async video generation for tests and local dev.
type MockClient struct{}

// Generate returns a deterministic mock MP4/H.264 URL or injects vendor errors via markers.
func (m *MockClient) Generate(ctx context.Context, req VendorRequest) (VideoResult, error) {
	if err := ctx.Err(); err != nil {
		return VideoResult{}, NormalizeHTTPStatus(0, err.Error())
	}

	marker := strings.ToLower(req.ObjectKey + " " + req.Prompt)
	switch {
	case strings.Contains(marker, "vendor_rate_limit"):
		return VideoResult{}, NormalizeVendorError("50411", http.StatusTooManyRequests, "qps limit")
	case strings.Contains(marker, "vendor_upstream"):
		return VideoResult{}, NormalizeVendorError("50500", http.StatusInternalServerError, "internal error")
	case strings.Contains(marker, "vendor_timeout"):
		return VideoResult{}, NormalizeHTTPStatus(http.StatusGatewayTimeout, "gateway timeout")
	case strings.Contains(marker, "vendor_face"):
		return VideoResult{}, NormalizeVendorError("60208", http.StatusOK, "face not detected")
	case strings.Contains(marker, "vendor_policy"):
		return VideoResult{}, NormalizeVendorError("40301", http.StatusOK, "content policy")
	case strings.Contains(marker, "vendor_invalid"):
		return VideoResult{}, NormalizeVendorError("40001", http.StatusBadRequest, "invalid parameter")
	case strings.Contains(marker, "vendor_bad_codec"):
		return VideoResult{}, NormalizeVendorError("INVALID_CODEC", http.StatusOK, "output codec hevc, want h264")
	}

	return VideoResult{
		URL:    "https://mock.seedance.local/out/" + strings.TrimPrefix(req.ObjectKey, "ai-tmp/") + ".mp4",
		Format: outputFormatMP4,
		Codec:  outputCodecH264,
	}, nil
}
