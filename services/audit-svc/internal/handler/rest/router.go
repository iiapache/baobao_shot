package rest

import (
	"net/http"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/config"
	"github.com/baobao/audit-svc/internal/middleware"
	"github.com/baobao/audit-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and audit routes.
func NewRouter(cfg *config.Config, st store.Store) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "audit-svc"}
	}
	if st == nil {
		st = store.NewMemoryStore()
	}

	health := NewHealthHandler(cfg.ServiceName)
	auditSvc := audit.NewService(st, nil)
	auditHandler := NewAuditHandler(auditSvc)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	r.Route("/v1", func(r chi.Router) {
		r.Post("/audit/sync", auditHandler.Sync)
		r.Post("/appeals", auditHandler.SubmitAppeal)
	})

	return r
}
