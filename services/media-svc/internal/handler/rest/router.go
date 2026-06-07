package rest

import (
	"net/http"

	"github.com/baobao/media-svc/internal/auth"
	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/middleware"
	"github.com/baobao/media-svc/internal/store"
	"github.com/baobao/media-svc/internal/upload"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and upload routes.
func NewRouter(cfg *config.Config, uploadStore store.UploadStore) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "media-svc", JWTSigningSecret: "dev-only-change-me"}
	}
	if uploadStore == nil {
		uploadStore = store.NewMemoryUploadStore()
	}

	health := NewHealthHandler(cfg.ServiceName)
	uploadSvc := upload.NewService(cfg, uploadStore, &upload.MockSTSProvider{})
	uploadHandler := NewUploadHandler(uploadSvc)
	validator := auth.NewValidator(cfg.JWTSigningSecret)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth(middleware.AuthOptions{Validator: validator}))

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	r.Route("/v1/uploads", func(r chi.Router) {
		r.Post("/init", uploadHandler.Init)
		r.Post("/complete", uploadHandler.Complete)
	})

	return r
}
