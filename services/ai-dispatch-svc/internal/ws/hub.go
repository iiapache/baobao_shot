package ws

import (
	"context"
	"sync"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/store"
)

// Config controls WebSocket hub timing and limits.
type Config struct {
	PingInterval time.Duration
	PongTimeout  time.Duration
}

// DefaultConfig returns production defaults (design-api §6.3).
func DefaultConfig() Config {
	return Config{
		PingInterval: 30 * time.Second,
		PongTimeout:  60 * time.Second,
	}
}

// Hub tracks active clients and task subscriptions.
type Hub struct {
	cfg   Config
	store store.TaskStore

	register   chan *Client
	unregister chan *Client
	broadcast  chan TaskEvent

	mu      sync.RWMutex
	clients map[*Client]struct{}
	// taskID -> clients subscribed to that task
	taskSubs map[string]map[*Client]struct{}
}

// NewHub creates a WebSocket hub.
func NewHub(taskStore store.TaskStore, cfg Config) *Hub {
	if cfg.PingInterval <= 0 {
		cfg.PingInterval = DefaultConfig().PingInterval
	}
	if cfg.PongTimeout <= 0 {
		cfg.PongTimeout = DefaultConfig().PongTimeout
	}
	return &Hub{
		cfg:        cfg,
		store:      taskStore,
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan TaskEvent, 256),
		clients:    make(map[*Client]struct{}),
		taskSubs:   make(map[string]map[*Client]struct{}),
	}
}

// Run processes hub lifecycle events until ctx is cancelled.
func (h *Hub) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.closeAll()
			return
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = struct{}{}
			h.mu.Unlock()
		case client := <-h.unregister:
			h.removeClient(client)
		case event := <-h.broadcast:
			h.deliverEvent(event)
		}
	}
}

// Register adds a connected client to the hub.
func (h *Hub) Register(client *Client) {
	h.register <- client
}

// Unregister removes a disconnected client from the hub.
func (h *Hub) Unregister(client *Client) {
	h.unregister <- client
}

// PublishTaskEvent pushes a task state event to subscribed clients.
func (h *Hub) PublishTaskEvent(_ context.Context, event TaskEvent) error {
	select {
	case h.broadcast <- event:
	default:
		// Drop when overloaded; clients can poll as fallback.
	}
	return nil
}

// Subscribe validates ownership and registers task subscriptions for a client.
func (h *Hub) Subscribe(ctx context.Context, client *Client, taskIDs []string) {
	accepted := make([]string, 0, len(taskIDs))
	for _, taskID := range taskIDs {
		if taskID == "" {
			continue
		}
		task, err := h.store.GetByID(ctx, taskID)
		if err != nil || task.UserID != client.userID {
			continue
		}
		accepted = append(accepted, taskID)
	}
	if len(accepted) == 0 {
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	for _, taskID := range accepted {
		client.taskIDs[taskID] = struct{}{}
		subs, ok := h.taskSubs[taskID]
		if !ok {
			subs = make(map[*Client]struct{})
			h.taskSubs[taskID] = subs
		}
		subs[client] = struct{}{}
	}
}

func (h *Hub) removeClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	delete(h.clients, client)
	for taskID := range client.taskIDs {
		if subs, ok := h.taskSubs[taskID]; ok {
			delete(subs, client)
			if len(subs) == 0 {
				delete(h.taskSubs, taskID)
			}
		}
	}
	client.taskIDs = make(map[string]struct{})
	close(client.send)
}

func (h *Hub) deliverEvent(event TaskEvent) {
	h.mu.RLock()
	subs := h.taskSubs[event.TaskID]
	targets := make([]*Client, 0, len(subs))
	for client := range subs {
		targets = append(targets, client)
	}
	h.mu.RUnlock()

	msg := ServerMessage{
		Op:           OpEvent,
		TaskID:       event.TaskID,
		State:        event.State,
		ResultURL:    event.ResultURL,
		ThumbnailURL: event.ThumbnailURL,
		DeepSynth:    event.DeepSynth,
		CostCredits:  event.CostCredits,
		BalanceAfter: event.BalanceAfter,
	}

	for _, client := range targets {
		select {
		case client.send <- msg:
		default:
			h.Unregister(client)
		}
	}
}

func (h *Hub) closeAll() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for client := range h.clients {
		close(client.send)
	}
	h.clients = make(map[*Client]struct{})
	h.taskSubs = make(map[string]map[*Client]struct{})
}

// ClientCount returns the number of connected clients (for tests).
func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}
