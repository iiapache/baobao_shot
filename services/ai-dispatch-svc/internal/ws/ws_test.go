package ws_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/auth"
	wshandler "github.com/baobao/ai-dispatch-svc/internal/handler/ws"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"github.com/baobao/ai-dispatch-svc/internal/ws"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
)

const testJWTSecret = "test-secret"

func TestWSConnectWithJWT(t *testing.T) {
	hub, srv, cancel := startTestServer(t, ws.Config{
		PingInterval: 30 * time.Second,
		PongTimeout:  60 * time.Second,
	})
	defer cancel()
	defer srv.Close()

	token := signAccessToken(t, "usr_alice", testJWTSecret)
	conn := dialWS(t, srv.URL, token)
	defer conn.Close()

	if hub.ClientCount() != 1 {
		t.Fatalf("client count = %d, want 1", hub.ClientCount())
	}
}

func TestWSRejectInvalidToken(t *testing.T) {
	_, srv, cancel := startTestServer(t, ws.DefaultConfig())
	defer cancel()
	defer srv.Close()

	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/v1/ws/ai?token=invalid"
	_, resp, err := websocket.DefaultDialer.Dial(url, nil)
	if err == nil {
		t.Fatal("expected dial failure for invalid token")
	}
	if resp == nil || resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %v, want 401", resp)
	}
}

func TestWSSubscribeAndReceiveEvent(t *testing.T) {
	taskStore := store.NewMemoryTaskStore()
	_ = taskStore.Create(context.Background(), &model.Task{
		ID:     "tsk_test_1",
		UserID: "usr_alice",
		State:  "running",
	})

	hub, srv, cancel := startTestServerWithStore(t, ws.DefaultConfig(), taskStore)
	defer cancel()
	defer srv.Close()

	conn := dialWS(t, srv.URL, "dev:usr_alice")
	defer conn.Close()

	sub := ws.ClientMessage{Op: ws.OpSubscribe, TaskIDs: []string{"tsk_test_1"}}
	if err := conn.WriteJSON(sub); err != nil {
		t.Fatalf("subscribe: %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	event := ws.TaskEvent{
		TaskID:       "tsk_test_1",
		State:        "succeeded",
		ResultURL:    "https://cdn.example/result.heic",
		ThumbnailURL: "https://cdn.example/thumb.jpg",
		CostCredits:  8,
		BalanceAfter: 92,
	}
	if err := hub.PublishTaskEvent(context.Background(), event); err != nil {
		t.Fatalf("publish: %v", err)
	}

	msg := readServerMessage(t, conn, 2*time.Second)
	if msg.Op != ws.OpEvent {
		t.Fatalf("op = %q, want event", msg.Op)
	}
	if msg.TaskID != "tsk_test_1" || msg.State != "succeeded" {
		t.Fatalf("event = %+v", msg)
	}
	if msg.ResultURL != event.ResultURL || msg.BalanceAfter != 92 {
		t.Fatalf("event payload incomplete: %+v", msg)
	}
}

func TestWSHeartbeatPingPong(t *testing.T) {
	_, srv, cancel := startTestServer(t, ws.Config{
		PingInterval: 100 * time.Millisecond,
		PongTimeout:  500 * time.Millisecond,
	})
	defer cancel()
	defer srv.Close()

	conn := dialWS(t, srv.URL, "dev:usr_alice")
	defer conn.Close()

	msg := readServerMessage(t, conn, 2*time.Second)
	if msg.Op != ws.OpPing {
		t.Fatalf("op = %q, want ping", msg.Op)
	}

	if err := conn.WriteJSON(ws.ClientMessage{Op: ws.OpPong}); err != nil {
		t.Fatalf("pong: %v", err)
	}

	// Second ping should arrive without disconnect.
	msg = readServerMessage(t, conn, 2*time.Second)
	if msg.Op != ws.OpPing {
		t.Fatalf("second op = %q, want ping", msg.Op)
	}
}

func TestWSReconnectAndResubscribe(t *testing.T) {
	taskStore := store.NewMemoryTaskStore()
	_ = taskStore.Create(context.Background(), &model.Task{
		ID:     "tsk_reconnect",
		UserID: "usr_alice",
		State:  "running",
	})

	hub, srv, cancel := startTestServerWithStore(t, ws.DefaultConfig(), taskStore)
	defer cancel()
	defer srv.Close()

	conn := dialWS(t, srv.URL, "dev:usr_alice")
	_ = conn.WriteJSON(ws.ClientMessage{Op: ws.OpSubscribe, TaskIDs: []string{"tsk_reconnect"}})
	time.Sleep(30 * time.Millisecond)
	_ = conn.Close()
	time.Sleep(50 * time.Millisecond)

	if hub.ClientCount() != 0 {
		t.Fatalf("client count after close = %d, want 0", hub.ClientCount())
	}

	conn2 := dialWS(t, srv.URL, "dev:usr_alice")
	defer conn2.Close()
	_ = conn2.WriteJSON(ws.ClientMessage{Op: ws.OpSubscribe, TaskIDs: []string{"tsk_reconnect"}})
	time.Sleep(30 * time.Millisecond)

	event := ws.TaskEvent{TaskID: "tsk_reconnect", State: "succeeded", ResultURL: "https://cdn.example/out.heic"}
	_ = hub.PublishTaskEvent(context.Background(), event)

	msg := readServerMessage(t, conn2, 2*time.Second)
	if msg.Op != ws.OpEvent || msg.State != "succeeded" {
		t.Fatalf("reconnected event = %+v", msg)
	}
}

func TestWSTimeoutDisconnect(t *testing.T) {
	hub, srv, cancel := startTestServer(t, ws.Config{
		PingInterval: 50 * time.Millisecond,
		PongTimeout:  150 * time.Millisecond,
	})
	defer cancel()
	defer srv.Close()

	conn := dialWS(t, srv.URL, "dev:usr_alice")

	// Ignore first ping, do not respond.
	readServerMessage(t, conn, 2*time.Second)

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if hub.ClientCount() == 0 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("client still connected after pong timeout")
}

func TestWSSubscribeRejectsForeignTask(t *testing.T) {
	taskStore := store.NewMemoryTaskStore()
	_ = taskStore.Create(context.Background(), &model.Task{
		ID:     "tsk_other",
		UserID: "usr_bob",
		State:  "running",
	})

	hub, srv, cancel := startTestServerWithStore(t, ws.DefaultConfig(), taskStore)
	defer cancel()
	defer srv.Close()

	conn := dialWS(t, srv.URL, "dev:usr_alice")
	defer conn.Close()

	sub := ws.ClientMessage{Op: ws.OpSubscribe, TaskIDs: []string{"tsk_other"}}
	if err := conn.WriteJSON(sub); err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	time.Sleep(50 * time.Millisecond)

	event := ws.TaskEvent{TaskID: "tsk_other", State: "succeeded"}
	_ = hub.PublishTaskEvent(context.Background(), event)

	conn.SetReadDeadline(time.Now().Add(300 * time.Millisecond))
	_, _, err := conn.ReadMessage()
	if err == nil {
		t.Fatal("expected no event for foreign task subscription")
	}
}

func startTestServer(t *testing.T, cfg ws.Config) (*ws.Hub, *httptest.Server, context.CancelFunc) {
	return startTestServerWithStore(t, cfg, store.NewMemoryTaskStore())
}

func startTestServerWithStore(t *testing.T, cfg ws.Config, taskStore store.TaskStore) (*ws.Hub, *httptest.Server, context.CancelFunc) {
	t.Helper()

	ctx, cancel := context.WithCancel(context.Background())
	hub := ws.NewHub(taskStore, cfg)
	go hub.Run(ctx)

	handler := wshandler.NewHandler(hub, auth.NewValidator(testJWTSecret))
	mux := http.NewServeMux()
	mux.Handle("/v1/ws/ai", handler)

	srv := httptest.NewServer(mux)
	return hub, srv, cancel
}

func dialWS(t *testing.T, baseURL, token string) *websocket.Conn {
	t.Helper()
	url := "ws" + strings.TrimPrefix(baseURL, "http") + "/v1/ws/ai?token=" + token
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial ws: %v", err)
	}
	return conn
}

func readServerMessage(t *testing.T, conn *websocket.Conn, timeout time.Duration) ws.ServerMessage {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(timeout))
	_, payload, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var msg ws.ServerMessage
	if err := json.Unmarshal(payload, &msg); err != nil {
		t.Fatalf("decode: %v", err)
	}
	return msg
}

func signAccessToken(t *testing.T, userID, secret string) string {
	t.Helper()
	now := time.Now().UTC()
	claims := auth.SessionClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Hour)),
		},
		Region: "cn",
		Typ:    "access",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return signed
}
