package apns

import (
	"encoding/json"
	"fmt"
	"strings"
)

// MarshalPayload builds the JSON body for an APNs HTTP/2 request.
func MarshalPayload(payload PushPayload) ([]byte, error) {
	body, err := buildPayloadBody(payload)
	if err != nil {
		return nil, err
	}
	return json.Marshal(body)
}

func buildPayloadBody(payload PushPayload) (map[string]any, error) {
	token := strings.TrimSpace(payload.DeviceToken)
	if token == "" {
		return nil, fmt.Errorf("device token required")
	}

	out := make(map[string]any)
	aps := make(map[string]any)

	if payload.Silent {
		aps["content-available"] = 1
	} else {
		alert := map[string]string{}
		if title := strings.TrimSpace(payload.Title); title != "" {
			alert["title"] = title
		}
		if body := strings.TrimSpace(payload.Body); body != "" {
			alert["body"] = body
		}
		if len(alert) == 0 {
			return nil, fmt.Errorf("alert push requires title or body")
		}
		aps["alert"] = alert
		aps["sound"] = "default"
	}

	out["aps"] = aps

	if category := strings.TrimSpace(payload.Category); category != "" {
		out["category"] = category
	}
	for key, value := range payload.CustomData {
		key = strings.TrimSpace(key)
		if key == "" || key == "category" {
			continue
		}
		out[key] = value
	}

	return out, nil
}

// PushType returns the APNs push-type header value.
func PushType(payload PushPayload) string {
	if payload.Silent {
		return "background"
	}
	return "alert"
}

// PriorityHeader returns the apns-priority header value.
func PriorityHeader(payload PushPayload) string {
	priority := payload.Priority
	if priority <= 0 {
		priority = 10
	}
	if payload.Silent && priority > 5 {
		// Silent background pushes should stay at normal priority unless explicitly lower.
		priority = 5
	}
	return fmt.Sprintf("%d", priority)
}
