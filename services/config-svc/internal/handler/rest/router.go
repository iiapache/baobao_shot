package rest

import (
	"net/http"

	"github.com/baobao/config-svc/internal/config"
	"github.com/baobao/config-svc/internal/middleware"
	"github.com/baobao/config-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and config endpoints.
func NewRouter(cfg *config.Config, s store.Store) http.Handler {
	health := NewHealthHandler(cfg.ServiceName)
	configHandler := NewConfigHandler(s)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	r.Route("/v1/config", func(r chi.Router) {
		r.Get("/features", configHandler.Features)
		r.Get("/product", configHandler.Product)
		r.Get("/plays", configHandler.Plays)
	})

	admin := NewAdminHandler(s, cfg.AdminToken)
	r.Route("/v1/admin", func(r chi.Router) {
		r.Patch("/features/{key}", admin.PatchFeature)
		r.Patch("/plays/{id}", admin.PatchPlay)
	})

	return r
}
