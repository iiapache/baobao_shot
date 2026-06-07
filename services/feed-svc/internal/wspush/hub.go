package wspush

import (
	"context"
	"strings"
	"sync"
	"time"
)

// Config controls WebSocket hub timing.
type Config struct {
	PingInterval time.Duration
	PongTimeout  time.Duration
}

// DefaultConfig returns production defaults aligned with design-api §6.3 heartbeat.
func DefaultConfig() Config {
	return Config{
		PingInterval: 30 * time.Second,
		PongTimeout:  60 * time.Second,
	}
}

// Hub tracks active clients and family subscriptions for feed deltas.
type Hub struct {
	cfg Config

	register   chan *client
	unregister chan *client
	broadcast  chan Event

	mu       sync.RWMutex
	clients  map[*client]struct{}
	familySubs map[string]map[*client]struct{}
}

// NewHub creates a feed WebSocket hub.
func NewHub(cfg Config) *Hub {
	if cfg.PingInterval <= 0 {
		cfg.PingInterval = DefaultConfig().PingInterval
	}
	if cfg.PongTimeout <= 0 {
		cfg.PongTimeout = DefaultConfig().PongTimeout
	}
	return &Hub{
		cfg:        cfg,
		register:   make(chan *client),
		unregister: make(chan *client),
		broadcast:  make(chan Event, 256),
		clients:    make(map[*client]struct{}),
		familySubs: make(map[string]map[*client]struct{}),
	}
}

// Run processes hub lifecycle events until ctx is cancelled.
func (h *Hub) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.closeAll()
			return
		case c := <-h.register:
			h.mu.Lock()
			h.clients[c] = struct{}{}
			h.mu.Unlock()
		case c := <-h.unregister:
			h.removeClient(c)
		case event := <-h.broadcast:
			h.deliverEvent(event)
		}
	}
}

// Register adds a connected client to the hub.
func (h *Hub) Register(c *client) {
	h.register <- c
}

// Unregister removes a disconnected client from the hub.
func (h *Hub) Unregister(c *client) {
	h.unregister <- c
}

// PublishFeedEvent pushes a feed delta to subscribed clients.
func (h *Hub) PublishFeedEvent(_ context.Context, event Event) error {
	select {
	case h.broadcast <- event:
	default:
		// Drop when overloaded; clients can poll feed as fallback.
	}
	return nil
}

// Subscribe registers family feed subscriptions for a client.
func (h *Hub) Subscribe(_ context.Context, c *client, familyIDs []string) {
	accepted := make([]string, 0, len(familyIDs))
	for _, familyID := range familyIDs {
		familyID = strings.TrimSpace(familyID)
		if familyID == "" {
			continue
		}
		accepted = append(accepted, familyID)
	}
	if len(accepted) == 0 {
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	for _, familyID := range accepted {
		c.familyIDs[familyID] = struct{}{}
		subs, ok := h.familySubs[familyID]
		if !ok {
			subs = make(map[*client]struct{})
			h.familySubs[familyID] = subs
		}
		subs[c] = struct{}{}
	}
}

func (h *Hub) removeClient(c *client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	delete(h.clients, c)
	for familyID := range c.familyIDs {
		if subs, ok := h.familySubs[familyID]; ok {
			delete(subs, c)
			if len(subs) == 0 {
				delete(h.familySubs, familyID)
			}
		}
	}
	c.familyIDs = make(map[string]struct{})
	close(c.send)
}

func (h *Hub) deliverEvent(event Event) {
	h.mu.RLock()
	subs := h.familySubs[event.FamilyID]
	targets := make([]*client, 0, len(subs))
	for c := range subs {
		targets = append(targets, c)
	}
	h.mu.RUnlock()

	msg := eventToServerMessage(event)
	for _, c := range targets {
		select {
		case c.send <- msg:
		default:
			h.Unregister(c)
		}
	}
}

func (h *Hub) closeAll() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.clients {
		close(c.send)
	}
	h.clients = make(map[*client]struct{})
	h.familySubs = make(map[string]map[*client]struct{})
}

// ClientCount returns the number of connected clients (for tests).
func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func eventToServerMessage(event Event) ServerMessage {
	msg := ServerMessage{
		Op:        OpEvent,
		Kind:      event.Kind,
		FamilyID:  event.FamilyID,
		PostID:    event.PostID,
		UserID:    event.UserID,
		CommentID: event.CommentID,
		Text:      event.Text,
	}
	if event.LikedAt != nil {
		msg.LikedAt = event.LikedAt.UTC().Format(time.RFC3339)
	}
	if event.CreatedAt != nil {
		msg.CreatedAt = event.CreatedAt.UTC().Format(time.RFC3339)
	}
	return msg
}
