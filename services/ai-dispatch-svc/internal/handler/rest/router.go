package rest

import (
	"net/http"

	"github.com/baobao/ai-dispatch-svc/internal/auditclient"
	"github.com/baobao/ai-dispatch-svc/internal/auth"
	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/costmetering"
	"github.com/baobao/ai-dispatch-svc/internal/middleware"
	"github.com/baobao/ai-dispatch-svc/internal/plays"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// RouterDeps carries optional handlers wired into the HTTP router.
type RouterDeps struct {
	WSHandler    http.Handler
	PlayCatalog  *plays.Catalog
	TaskStore    store.TaskStore
	AuditClient  auditclient.Client
	CostMetering *costmetering.Service
}

// NewRouter builds the REST API router with health probes.
func NewRouter(cfg *config.Config, deps RouterDeps) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "ai-dispatch-svc", JWTSigningSecret: "dev-only-change-me"}
	}

	health := NewHealthHandler(cfg.ServiceName)
	validator := auth.NewValidator(cfg.JWTSigningSecret)

	var playsHandler *PlaysHandler
	if deps.PlayCatalog != nil {
		playsHandler = NewPlaysHandler(deps.PlayCatalog)
	}

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth(middleware.AuthOptions{Validator: validator}))

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	if playsHandler != nil {
		r.Get("/v1/ai/plays", playsHandler.List)
	}

	if deps.TaskStore != nil && deps.AuditClient != nil {
		appealHandler := NewAppealHandler(deps.TaskStore, deps.AuditClient)
		r.Post("/v1/ai/tasks/{taskId}/appeal", appealHandler.Appeal)
	}

	if deps.WSHandler != nil {
		r.Get("/v1/ws/ai", deps.WSHandler.ServeHTTP)
	}

	if deps.CostMetering != nil {
		costHandler := NewCostMeteringHandler(deps.CostMetering)
		r.Get("/internal/v1/cost-metering/tasks/{taskId}", costHandler.TaskCosts)
		r.Get("/internal/v1/cost-metering/weekly-report", costHandler.WeeklyReport)
	}

	return r
}
