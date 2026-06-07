package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const writeWait = 10 * time.Second

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// Client represents a single WebSocket connection.
type Client struct {
	hub     *Hub
	userID  string
	conn    *websocket.Conn
	send    chan ServerMessage
	taskIDs map[string]struct{}

	lastPongMu sync.Mutex
	lastPong   time.Time
}

// NewClient creates a client bound to an upgraded connection.
func NewClient(hub *Hub, userID string, conn *websocket.Conn) *Client {
	now := time.Now()
	return &Client{
		hub:     hub,
		userID:  userID,
		conn:    conn,
		send:    make(chan ServerMessage, 16),
		taskIDs: make(map[string]struct{}),
		lastPong: now,
	}
}

// ServeHTTP upgrades the connection and runs read/write pumps.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request, userID string) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("ws upgrade failed", "error", err)
		return
	}

	client := NewClient(h, userID, conn)
	h.Register(client)

	go client.writePump()
	go client.readPump(r.Context())
}

func (c *Client) readPump(ctx context.Context) {
	defer func() {
		c.hub.Unregister(c)
		_ = c.conn.Close()
	}()

	_ = c.conn.SetReadDeadline(time.Now().Add(c.hub.cfg.PongTimeout))
	c.conn.SetPongHandler(func(string) error {
		c.touchPong()
		_ = c.conn.SetReadDeadline(time.Now().Add(c.hub.cfg.PongTimeout))
		return nil
	})

	for {
		_, payload, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				slog.Debug("ws read closed", "userId", c.userID, "error", err)
			}
			return
		}

		c.touchPong()
		_ = c.conn.SetReadDeadline(time.Now().Add(c.hub.cfg.PongTimeout))

		var msg ClientMessage
		if err := json.Unmarshal(payload, &msg); err != nil {
			c.enqueue(ServerMessage{Op: OpError, Code: "INVALID_JSON", Message: "invalid message"})
			continue
		}

		switch msg.Op {
		case OpPong:
			// application-level pong; deadline already refreshed
		case OpSubscribe:
			c.hub.Subscribe(ctx, c, msg.TaskIDs)
		default:
			c.enqueue(ServerMessage{Op: OpError, Code: "UNKNOWN_OP", Message: "unsupported op"})
		}
	}
}

func (c *Client) writePump() {
	pingTicker := time.NewTicker(c.hub.cfg.PingInterval)
	defer func() {
		pingTicker.Stop()
		_ = c.conn.Close()
	}()

	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteJSON(msg); err != nil {
				return
			}
		case <-pingTicker.C:
			if c.pongExpired() {
				return
			}
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteJSON(ServerMessage{Op: OpPing}); err != nil {
				return
			}
		}
	}
}

func (c *Client) enqueue(msg ServerMessage) {
	select {
	case c.send <- msg:
	default:
		c.hub.Unregister(c)
	}
}

func (c *Client) touchPong() {
	c.lastPongMu.Lock()
	c.lastPong = time.Now()
	c.lastPongMu.Unlock()
}

func (c *Client) pongExpired() bool {
	c.lastPongMu.Lock()
	defer c.lastPongMu.Unlock()
	return time.Since(c.lastPong) >= c.hub.cfg.PongTimeout
}
