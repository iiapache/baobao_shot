package aliyun

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHTTPClient_TextPass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/green/text/scan" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"code": 200,
			"data": []map[string]any{
				{
					"code": 200,
					"results": []map[string]any{
						{"scene": "antispam", "suggestion": "pass"},
					},
				},
			},
		})
	}))
	defer srv.Close()

	client := &HTTPClient{Endpoint: srv.URL, TextScenes: "antispam"}
	passed, reasons, err := client.AuditText(context.Background(), "hello", "")
	if err != nil {
		t.Fatalf("AuditText() error = %v", err)
	}
	if !passed || len(reasons) != 0 {
		t.Fatalf("passed=%v reasons=%v", passed, reasons)
	}
}

func TestHTTPClient_TextReject(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"code": 200,
			"data": []map[string]any{
				{
					"code": 200,
					"results": []map[string]any{
						{"scene": "antispam", "suggestion": "block", "label": "spam"},
					},
				},
			},
		})
	}))
	defer srv.Close()

	client := &HTTPClient{Endpoint: srv.URL}
	passed, reasons, err := client.AuditText(context.Background(), "reject_spam", "")
	if err != nil {
		t.Fatalf("AuditText() error = %v", err)
	}
	if passed || len(reasons) != 1 || reasons[0] != "antispam" {
		t.Fatalf("passed=%v reasons=%v", passed, reasons)
	}
}

func TestHTTPClient_ImageUsesObjectURL(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/green/image/scan" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			t.Fatalf("decode body: %v", err)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"code": 200,
			"data": []map[string]any{{"code": 200, "results": []map[string]any{{"scene": "porn", "suggestion": "pass"}}}},
		})
	}))
	defer srv.Close()

	client := &HTTPClient{
		Endpoint:        srv.URL,
		ObjectURLPrefix: "https://cdn.example.com",
		ImageScenes:     "porn",
	}
	if _, _, err := client.AuditImage(context.Background(), "family/fam_1/out.jpg", ""); err != nil {
		t.Fatalf("AuditImage() error = %v", err)
	}
	tasks, ok := got["tasks"].([]any)
	if !ok || len(tasks) == 0 {
		t.Fatalf("tasks = %#v", got["tasks"])
	}
	task, ok := tasks[0].(map[string]any)
	if !ok || task["url"] != "https://cdn.example.com/family/fam_1/out.jpg" {
		t.Fatalf("url = %#v", task["url"])
	}
}

func TestParseScanResponse_APIError(t *testing.T) {
	_, _, err := parseScanResponse([]byte(`{"code":500,"msg":"fail"}`))
	if err == nil {
		t.Fatal("expected error for non-200 code")
	}
}
