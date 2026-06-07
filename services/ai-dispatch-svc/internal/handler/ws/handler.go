package wshandler

import (
	"net/http"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/auth"
	"github.com/baobao/ai-dispatch-svc/internal/ws"
)

// Handler upgrades HTTP requests to WebSocket connections at /v1/ws/ai.
type Handler struct {
	hub       *ws.Hub
	validator *auth.Validator
}

// NewHandler creates the AI task WebSocket handler.
func NewHandler(hub *ws.Hub, validator *auth.Validator) *Handler {
	return &Handler{hub: hub, validator: validator}
}

// ServeHTTP validates JWT from ?token= and upgrades the connection.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.authenticate(r)
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	h.hub.ServeHTTP(w, r, userID)
}

func (h *Handler) authenticate(r *http.Request) (string, bool) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		return "", false
	}

	if userID := auth.ParseDevToken(token); userID != "" {
		return userID, true
	}

	if h.validator == nil {
		return "", false
	}
	claims, err := h.validator.ParseAccess(token)
	if err != nil {
		return "", false
	}
	return claims.Subject, true
}
