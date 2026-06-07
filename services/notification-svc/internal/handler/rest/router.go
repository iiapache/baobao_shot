package rest

import (
	"net/http"

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/device"
	"github.com/baobao/notification-svc/internal/inbox"
	"github.com/baobao/notification-svc/internal/middleware"
	"github.com/baobao/notification-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and notification routes.
func NewRouter(cfg *config.Config, st store.Store, apnsClient *apns.Client) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "notification-svc", DebugEndpoints: true}
	}
	if st == nil {
		st = store.NewMemoryStore()
	}

	deviceSvc := device.NewService(st)
	inboxSvc := inbox.NewService(st)
	devices := NewDeviceHandler(deviceSvc)
	notifications := NewNotificationHandler(inboxSvc)
	health := NewHealthHandler(cfg.ServiceName)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth)

	r.Get("/health", health.Live)
	r.Get("/ready", func(w http.ResponseWriter, r *http.Request) {
		if err := st.Ping(r.Context()); err != nil {
			health.SetReady(false)
		} else {
			health.SetReady(true)
		}
		health.Ready(w, r)
	})

	r.Post("/v1/notifications/devices", devices.Register)
	r.Delete("/v1/notifications/devices/{deviceId}", devices.Unregister)
	r.Get("/v1/notifications", notifications.List)
	r.Post("/v1/notifications/mark-read", notifications.MarkRead)
	r.Get("/v1/notifications/subscriptions", notifications.GetSubscriptions)
	r.Patch("/v1/notifications/subscriptions", notifications.UpdateSubscriptions)
	r.Post("/v1/internal/notifications/tokens/cleanup", devices.CleanupInvalidToken)

	if cfg.DebugEndpoints && apnsClient != nil {
		debug := NewDebugHandler(apnsClient, cfg.APNSMock)
		r.Post("/v1/debug/apns-ping", debug.APNsPing)
	}

	return r
}
