package wspush

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

type client struct {
	hub       *Hub
	userID    string
	conn      *websocket.Conn
	send      chan ServerMessage
	familyIDs map[string]struct{}

	lastPongMu sync.Mutex
	lastPong   time.Time
}

func newClient(hub *Hub, userID string, conn *websocket.Conn) *client {
	now := time.Now()
	return &client{
		hub:       hub,
		userID:    userID,
		conn:      conn,
		send:      make(chan ServerMessage, 16),
		familyIDs: make(map[string]struct{}),
		lastPong:  now,
	}
}

// ServeHTTP upgrades the connection and runs read/write pumps.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request, userID string) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		slog.Error("feed ws upgrade failed", "error", err)
		return
	}

	c := newClient(h, userID, conn)
	h.Register(c)

	go c.writePump()
	go c.readPump(r.Context())
}

func (c *client) readPump(ctx context.Context) {
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
				slog.Debug("feed ws read closed", "userId", c.userID, "error", err)
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
		case OpSubscribe:
			c.hub.Subscribe(ctx, c, msg.FamilyIDs)
		default:
			c.enqueue(ServerMessage{Op: OpError, Code: "UNKNOWN_OP", Message: "unsupported op"})
		}
	}
}

func (c *client) writePump() {
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

func (c *client) enqueue(msg ServerMessage) {
	select {
	case c.send <- msg:
	default:
		c.hub.Unregister(c)
	}
}

func (c *client) touchPong() {
	c.lastPongMu.Lock()
	c.lastPong = time.Now()
	c.lastPongMu.Unlock()
}

func (c *client) pongExpired() bool {
	c.lastPongMu.Lock()
	defer c.lastPongMu.Unlock()
	return time.Since(c.lastPong) >= c.hub.cfg.PongTimeout
}
