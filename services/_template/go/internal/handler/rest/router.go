package rest

import (
	"net/http"

	"github.com/baobao/template/internal/config"
	"github.com/baobao/template/internal/middleware"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and middleware.
func NewRouter(cfg *config.Config) http.Handler {
	health := NewHealthHandler(cfg.ServiceName)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.Auth)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	// Business routes go here, e.g. r.Route("/v1", ...)

	return r
}
