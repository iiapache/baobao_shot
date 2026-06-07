package apns

import (
	"encoding/json"
	"testing"
)

func TestMarshalPayloadSilentAIDone(t *testing.T) {
	body, err := MarshalPayload(PushPayload{
		DeviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
		Silent:      true,
		Category:    "AI_DONE",
		CustomData: map[string]string{
			"taskId":    "tsk_1",
			"state":     "succeeded",
			"resultUrl": "https://cdn.example/result.heic",
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatal(err)
	}

	aps, ok := decoded["aps"].(map[string]any)
	if !ok {
		t.Fatalf("aps = %#v", decoded["aps"])
	}
	if aps["content-available"] != float64(1) {
		t.Fatalf("content-available = %#v", aps["content-available"])
	}
	if _, hasAlert := aps["alert"]; hasAlert {
		t.Fatal("silent payload should not include alert")
	}
	if decoded["category"] != "AI_DONE" {
		t.Fatalf("category = %#v", decoded["category"])
	}
	if decoded["taskId"] != "tsk_1" {
		t.Fatalf("taskId = %#v", decoded["taskId"])
	}
}

func TestMarshalPayloadAlert(t *testing.T) {
	body, err := MarshalPayload(PushPayload{
		DeviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
		Title:       "AI 任务完成",
		Body:        "作品已生成",
		Category:    "AI_DONE",
		CustomData: map[string]string{
			"taskId": "tsk_1",
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatal(err)
	}

	aps := decoded["aps"].(map[string]any)
	alert := aps["alert"].(map[string]any)
	if alert["title"] != "AI 任务完成" {
		t.Fatalf("title = %#v", alert["title"])
	}
	if PushType(PushPayload{Silent: true}) != "background" {
		t.Fatal("silent push type should be background")
	}
	if PushType(PushPayload{Title: "x"}) != "alert" {
		t.Fatal("alert push type should be alert")
	}
}

func TestValidateSenderConfigLiveRequiresCredentials(t *testing.T) {
	if err := ValidateSenderConfig(SenderConfig{Mock: false}); err == nil {
		t.Fatal("expected error for live mode without credentials")
	}
	if err := ValidateSenderConfig(SenderConfig{Mock: true}); err != nil {
		t.Fatalf("mock mode should not require credentials: %v", err)
	}
}

func TestNewSenderMockMode(t *testing.T) {
	sender, err := NewSender(SenderConfig{Mock: true})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := sender.(*MockSender); !ok {
		t.Fatalf("sender type = %T", sender)
	}
}
