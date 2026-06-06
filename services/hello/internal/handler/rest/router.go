package rest

import (
	"net/http"

	"github.com/baobao/hello/internal/config"
	"github.com/baobao/hello/internal/middleware"
	"github.com/go-chi/chi/v5"
)

func NewRouter(cfg *config.Config) http.Handler {
	health := NewHealthHandler(cfg.ServiceName)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.Auth)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	r.Get("/v1/echo", echoHandler)

	return r
}

func echoHandler(w http.ResponseWriter, r *http.Request) {
	msg := r.URL.Query().Get("msg")
	if msg == "" {
		msg = "hello from baobao"
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"message": msg,
		"service": "hello",
	})
}