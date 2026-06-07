package wspush

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestStubRecordsEvents(t *testing.T) {
	stub := NewStub()
	now := time.Now().UTC()
	if err := stub.PublishFeedEvent(context.Background(), Event{
		Kind: KindLikeAdded, FamilyID: "fam_1", PostID: "post_1", UserID: "usr_1", LikedAt: &now,
	}); err != nil {
		t.Fatal(err)
	}
	if len(stub.Events()) != 1 {
		t.Fatalf("events = %d", len(stub.Events()))
	}
}

func TestHubPublishToSubscribedClient(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	hub := NewHub(Config{PingInterval: time.Hour, PongTimeout: 2 * time.Hour})
	go hub.Run(ctx)

	mux := http.NewServeMux()
	mux.HandleFunc("/v1/ws/feed", func(w http.ResponseWriter, r *http.Request) {
		hub.ServeHTTP(w, r, "usr_ws")
	})
	srv := httptest.NewServer(mux)
	defer srv.Close()

	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/v1/ws/feed"
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	if err := conn.WriteJSON(ClientMessage{Op: OpSubscribe, FamilyIDs: []string{"fam_hub"}}); err != nil {
		t.Fatal(err)
	}
	time.Sleep(30 * time.Millisecond)

	now := time.Now().UTC()
	if err := hub.PublishFeedEvent(context.Background(), Event{
		Kind: KindCommentAdded, FamilyID: "fam_hub", PostID: "post_1", UserID: "usr_1",
		CommentID: "cmt_1", Text: "hi", CreatedAt: &now,
	}); err != nil {
		t.Fatal(err)
	}

	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, payload, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var msg ServerMessage
	if err := json.Unmarshal(payload, &msg); err != nil {
		t.Fatal(err)
	}
	if msg.Op != OpEvent || msg.Kind != KindCommentAdded || msg.CommentID != "cmt_1" {
		t.Fatalf("msg = %+v", msg)
	}
}
