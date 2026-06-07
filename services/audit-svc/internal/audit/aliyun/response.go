package aliyun

import (
	"encoding/json"
	"fmt"
	"strings"
)

type scanResponse struct {
	Code int              `json:"code"`
	Msg  string           `json:"msg"`
	Data []scanDataResult `json:"data"`
}

type scanDataResult struct {
	Code    int          `json:"code"`
	Msg     string       `json:"msg"`
	Results []scanResult `json:"results"`
}

type scanResult struct {
	Scene      string  `json:"scene"`
	Label      string  `json:"label"`
	Suggestion string  `json:"suggestion"`
	Rate       float64 `json:"rate"`
}

func parseScanResponse(raw []byte) (bool, []string, error) {
	var resp scanResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return false, nil, fmt.Errorf("decode green response: %w", err)
	}
	if resp.Code != 200 {
		return false, nil, fmt.Errorf("green api code %d: %s", resp.Code, resp.Msg)
	}
	if len(resp.Data) == 0 {
		return true, nil, nil
	}
	item := resp.Data[0]
	if item.Code != 200 {
		return false, nil, fmt.Errorf("green task code %d: %s", item.Code, item.Msg)
	}

	var reasons []string
	for _, result := range item.Results {
		suggestion := strings.ToLower(strings.TrimSpace(result.Suggestion))
		if suggestion == "pass" || suggestion == "" {
			continue
		}
		reason := strings.TrimSpace(result.Scene)
		if reason == "" {
			reason = strings.TrimSpace(result.Label)
		}
		if reason == "" {
			reason = suggestion
		}
		reasons = appendUnique(reasons, reason)
	}
	return len(reasons) == 0, reasons, nil
}

func appendUnique(items []string, value string) []string {
	for _, existing := range items {
		if existing == value {
			return items
		}
	}
	return append(items, value)
}

func splitScenes(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func objectURL(prefix, objectKey string) string {
	key := strings.TrimPrefix(strings.TrimSpace(objectKey), "/")
	if strings.HasPrefix(key, "http://") || strings.HasPrefix(key, "https://") {
		return key
	}
	base := strings.TrimRight(strings.TrimSpace(prefix), "/")
	if base == "" {
		base = "https://oss-mock.example.com"
	}
	return base + "/" + key
}
