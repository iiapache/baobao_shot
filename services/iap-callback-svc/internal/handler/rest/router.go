package rest

import (
	"net/http"

	"github.com/baobao/iap-callback-svc/internal/config"
	"github.com/baobao/iap-callback-svc/internal/middleware"
	"github.com/baobao/iap-callback-svc/internal/processor"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and Apple ASN routes.
func NewRouter(cfg *config.Config, proc *processor.Service) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "iap-callback-svc"}
	}

	health := NewHealthHandler(cfg.ServiceName)
	asnHandler := NewAppleNotificationHandler(proc)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)
	r.Post("/v1/apple/notifications", asnHandler.Notify)

	return r
}
