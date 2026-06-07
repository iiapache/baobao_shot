package configclient

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestStubDefaultFeaturesEnabled(t *testing.T) {
	stub := NewStub(nil)
	features, err := stub.Features(context.Background(), Request{Region: "cn", UserID: "usr_1"})
	if err != nil {
		t.Fatal(err)
	}
	if !features["ai.play.ghibli_kid"].Enabled {
		t.Fatal("expected ghibli_kid enabled")
	}
}

func TestStubSetFeature(t *testing.T) {
	stub := NewStub(nil)
	stub.SetFeature("ai.play.ghibli_kid", false)
	features, _ := stub.Features(context.Background(), Request{Region: "cn"})
	if features["ai.play.ghibli_kid"].Enabled {
		t.Fatal("expected disabled after SetFeature")
	}
}

func TestHTTPClientFeatures(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/config/features" {
			http.NotFound(w, r)
			return
		}
		if r.Header.Get("X-Region") != "cn" {
			t.Errorf("X-Region = %q, want cn", r.Header.Get("X-Region"))
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"code": "OK",
			"data": map[string]any{
				"features": map[string]any{
					"ai.play.video_walk": map[string]any{"enabled": false},
				},
			},
		})
	}))
	defer srv.Close()

	client := NewHTTPClient(srv.URL)
	features, err := client.Features(context.Background(), Request{
		Region:     "cn",
		AppVersion: "1.0.0",
		UserID:     "usr_http",
	})
	if err != nil {
		t.Fatal(err)
	}
	if features["ai.play.video_walk"].Enabled {
		t.Fatal("expected video_walk disabled from HTTP stub")
	}
}
