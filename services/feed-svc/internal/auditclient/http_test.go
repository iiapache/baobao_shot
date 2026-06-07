package auditclient

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHTTPClient_AuditTextSync(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/audit/sync" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		var body syncAuditRequest
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if body.Kind != "ugc" || body.MediaType != "text" {
			t.Fatalf("body = %+v", body)
		}
		_ = json.NewEncoder(w).Encode(syncAuditResponse{
			JobID:  "aud_test",
			Status: "passed",
			Result: "passed",
			Vendor: "aliyun-green",
		})
	}))
	defer srv.Close()

	client := NewHTTPClient(srv.URL)
	result, err := client.AuditTextSync(context.Background(), TextAuditRequest{
		TargetRef: "post_1",
		Region:    "cn",
		Text:      "hello",
	})
	if err != nil {
		t.Fatalf("AuditTextSync() error = %v", err)
	}
	if !result.Passed || result.JobID != "aud_test" {
		t.Fatalf("result = %+v", result)
	}
}

func TestHTTPClient_EnqueueMediaAsyncReject(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(syncAuditResponse{
			JobID:   "aud_media",
			Status:  "rejected",
			Result:  "rejected",
			Reasons: []string{"porn"},
			Vendor:  "aliyun-green",
		})
	}))
	defer srv.Close()

	client := NewHTTPClient(srv.URL)
	result, err := client.EnqueueMediaAsync(context.Background(), MediaAuditRequest{
		TargetRef: "post_1",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/reject_porn.jpg",
	})
	if err != nil {
		t.Fatalf("EnqueueMediaAsync() error = %v", err)
	}
	if result.Passed || len(result.Reasons) != 1 {
		t.Fatalf("result = %+v", result)
	}
}
