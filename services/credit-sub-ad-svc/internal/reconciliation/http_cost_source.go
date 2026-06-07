package reconciliation

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const weeklyReportPath = "/internal/v1/cost-metering/weekly-report"

// HTTPCostMeteringSource loads weekly totals from ai-dispatch-svc.
type HTTPCostMeteringSource struct {
	BaseURL string
	Client  *http.Client
}

type weeklyReportPayload struct {
	WeekStart    time.Time `json:"weekStart"`
	WeekEnd      time.Time `json:"weekEnd"`
	TotalCredits int64     `json:"totalCredits"`
}

// WeeklyTotalCredits fetches the weekly cost metering report for weekStart (Mon 00:00 UTC).
func (s *HTTPCostMeteringSource) WeeklyTotalCredits(ctx context.Context, weekStart time.Time) (int64, error) {
	if s == nil || strings.TrimSpace(s.BaseURL) == "" {
		return 0, ErrCostSourceUnavailable
	}
	client := s.Client
	if client == nil {
		client = http.DefaultClient
	}

	endpoint, err := url.Parse(strings.TrimRight(s.BaseURL, "/") + weeklyReportPath)
	if err != nil {
		return 0, fmt.Errorf("parse cost metering url: %w", err)
	}
	q := endpoint.Query()
	q.Set("weekStart", weekStart.UTC().Format(time.RFC3339))
	endpoint.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint.String(), nil)
	if err != nil {
		return 0, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, err
	}
	if resp.StatusCode != http.StatusOK {
		slog.Warn("cost metering weekly report failed", "status", resp.StatusCode, "body", string(body))
		return 0, fmt.Errorf("cost metering weekly report status %d", resp.StatusCode)
	}

	var payload weeklyReportPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return 0, err
	}
	return payload.TotalCredits, nil
}

// CreditsConsumedInPeriod compares ledger totals with ai-dispatch weekly reports for full UTC weeks.
func (s *HTTPCostMeteringSource) CreditsConsumedInPeriod(ctx context.Context, start, end time.Time) (int64, error) {
	start = start.UTC()
	end = end.UTC()
	weekStart := weekStartUTC(start)
	weekEnd := weekStart.AddDate(0, 0, 7)
	if !start.Equal(weekStart) || !end.Equal(weekEnd) {
		return 0, ErrCostSourceUnavailable
	}
	return s.WeeklyTotalCredits(ctx, weekStart)
}

func weekStartUTC(t time.Time) time.Time {
	t = t.UTC()
	weekday := int(t.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -(weekday - 1))
}

// NewHTTPCostMeteringSource creates a cost source when baseURL is non-empty.
func NewHTTPCostMeteringSource(baseURL string) CostMeteringSource {
	if strings.TrimSpace(baseURL) == "" {
		return NopCostSource{}
	}
	return &HTTPCostMeteringSource{BaseURL: baseURL}
}
