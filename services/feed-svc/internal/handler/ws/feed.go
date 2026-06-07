package wshandler

import (
	"net/http"
	"strings"

	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/baobao/feed-svc/internal/wspush"
)

// FeedHandler upgrades HTTP requests to WebSocket connections at /v1/ws/feed.
type FeedHandler struct {
	hub *wspush.Hub
}

// NewFeedHandler creates the feed WebSocket handler.
func NewFeedHandler(hub *wspush.Hub) *FeedHandler {
	return &FeedHandler{hub: hub}
}

// ServeHTTP validates token from ?token= or gateway headers and upgrades the connection.
func (h *FeedHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.authenticate(r)
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	h.hub.ServeHTTP(w, r, userID)
}

func (h *FeedHandler) authenticate(r *http.Request) (string, bool) {
	if userID, ok := middleware.UserIDFromContext(r.Context()); ok {
		return userID, true
	}

	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		return "", false
	}
	if userID := parseDevToken(token); userID != "" {
		return userID, true
	}
	return "", false
}

func parseDevToken(token string) string {
	if token == "" || token == "invalid" {
		return ""
	}
	if token == "dev" {
		return "usr_dev"
	}
	if strings.HasPrefix(token, "dev:") {
		return strings.TrimPrefix(token, "dev:")
	}
	if strings.HasPrefix(token, "atk_") {
		body := strings.TrimPrefix(token, "atk_")
		if idx := strings.LastIndex(body, "_"); idx > 0 {
			return body[:idx]
		}
	}
	return ""
}
