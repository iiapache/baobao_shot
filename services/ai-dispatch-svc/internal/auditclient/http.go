package auditclient

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

// HTTPClient calls audit-svc POST /v1/appeals with targetRef.
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

type submitAppealBody struct {
	TargetRef string `json:"targetRef"`
	UserID    string `json:"userId"`
	Reason    string `json:"reason"`
}

type submitAppealResponseBody struct {
	AppealID string `json:"appealId"`
	Status   string `json:"status"`
}

// SubmitAppealForTask submits an appeal via audit-svc REST.
func (c *HTTPClient) SubmitAppealForTask(ctx context.Context, req SubmitAppealRequest) (*SubmitAppealResponse, error) {
	reason := strings.TrimSpace(req.Reason)
	if reason == "" {
		return nil, ErrMissingReason
	}
	body, err := json.Marshal(submitAppealBody{
		TargetRef: req.TaskID,
		UserID:    req.UserID,
		Reason:    reason,
	})
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/appeals", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpstream, err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}

	switch resp.StatusCode {
	case http.StatusCreated:
		var parsed submitAppealResponseBody
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return nil, fmt.Errorf("decode audit-svc response: %w", err)
		}
		return &SubmitAppealResponse{
			AppealID: parsed.AppealID,
			Status:   parsed.Status,
		}, nil
	case http.StatusBadRequest:
		if strings.Contains(string(raw), "appeal reason required") {
			return nil, ErrMissingReason
		}
		return nil, fmt.Errorf("%w: status %d", ErrAppealNotAllowed, resp.StatusCode)
	case http.StatusNotFound:
		return nil, ErrAuditJobNotFound
	case http.StatusConflict:
		if strings.Contains(string(raw), "already exists") {
			return nil, ErrAppealDuplicate
		}
		return nil, ErrAppealNotAllowed
	default:
		return nil, fmt.Errorf("%w: status %d: %s", ErrUpstream, resp.StatusCode, string(raw))
	}
}

// MapAuditError normalizes audit-svc errors for REST handlers.
func MapAuditError(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, ErrMissingReason),
		errors.Is(err, ErrAuditJobNotFound),
		errors.Is(err, ErrAppealNotAllowed),
		errors.Is(err, ErrAppealDuplicate):
		return err
	default:
		return ErrUpstream
	}
}
