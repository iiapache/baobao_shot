package auditclient

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

// HTTPClient calls audit-svc REST endpoints for UGC moderation.
type HTTPClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewHTTPClient creates an audit-svc HTTP client.
func NewHTTPClient(baseURL string) *HTTPClient {
	return &HTTPClient{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

type syncAuditRequest struct {
	Kind      string `json:"kind"`
	TargetRef string `json:"targetRef"`
	Region    string `json:"region"`
	MediaType string `json:"mediaType,omitempty"`
	ObjectKey string `json:"objectKey,omitempty"`
	Text      string `json:"text,omitempty"`
}

type syncAuditResponse struct {
	JobID   string   `json:"jobId"`
	Status  string   `json:"status"`
	Result  string   `json:"result"`
	Reasons []string `json:"reasons"`
	Vendor  string   `json:"vendor"`
}

// AuditTextSync runs synchronous UGC text moderation via audit-svc.
func (c *HTTPClient) AuditTextSync(ctx context.Context, req TextAuditRequest) (Result, error) {
	return c.syncAudit(ctx, syncAuditRequest{
		Kind:      "ugc",
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: "text",
		Text:      req.Text,
	})
}

// EnqueueMediaAsync runs synchronous media moderation and returns the audit job id.
func (c *HTTPClient) EnqueueMediaAsync(ctx context.Context, req MediaAuditRequest) (Result, error) {
	return c.syncAudit(ctx, syncAuditRequest{
		Kind:      "ugc",
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: req.MediaType,
		ObjectKey: req.ObjectKey,
	})
}

func (c *HTTPClient) syncAudit(ctx context.Context, body syncAuditRequest) (Result, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return Result{}, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/audit/sync", bytes.NewReader(payload))
	if err != nil {
		return Result{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return Result{}, fmt.Errorf("audit-svc request: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Result{}, err
	}
	if resp.StatusCode != http.StatusOK {
		return Result{}, fmt.Errorf("audit-svc status %d: %s", resp.StatusCode, string(raw))
	}

	var parsed syncAuditResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return Result{}, fmt.Errorf("decode audit-svc response: %w", err)
	}
	return Result{
		JobID:   parsed.JobID,
		Passed:  parsed.Status == "passed",
		Reasons: parsed.Reasons,
	}, nil
}
