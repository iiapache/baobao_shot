package rest

import (
	"context"
	"net/http"

	"github.com/baobao/feed-svc/internal/auditclient"
	"github.com/baobao/feed-svc/internal/cache"
	"github.com/baobao/feed-svc/internal/config"
	"github.com/baobao/feed-svc/internal/engagement"
	"github.com/baobao/feed-svc/internal/familyauth"
	"github.com/baobao/feed-svc/internal/feed"
	wshandler "github.com/baobao/feed-svc/internal/handler/ws"
	"github.com/baobao/feed-svc/internal/mediaclient"
	"github.com/baobao/feed-svc/internal/middleware"
	"github.com/baobao/feed-svc/internal/post"
	"github.com/baobao/feed-svc/internal/ratelimit"
	"github.com/baobao/feed-svc/internal/reconciliation"
	"github.com/baobao/feed-svc/internal/store"
	"github.com/baobao/feed-svc/internal/wspush"
	"github.com/go-chi/chi/v5"
)

// RouterDeps wires optional runtime collaborators into the HTTP router.
type RouterDeps struct {
	MediaStub mediaclient.Client
}

// NewRouter builds the REST API router with health probes and feed WebSocket stub.
func NewRouter(cfg *config.Config, st store.Store, deps RouterDeps) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "feed-svc"}
	}
	if st == nil {
		st = store.NewMemoryStore()
	}
	media := deps.MediaStub
	if media == nil {
		media = mediaclient.NewStub()
	}

	hub := wspush.NewHub(wspush.DefaultConfig())
	go hub.Run(context.Background())

	health := NewHealthHandler(cfg.ServiceName)
	postSvc := post.NewService(st, auditclient.NewStub(), ratelimit.NewSlidingWindow(), media)
	postHandler := NewPostHandler(postSvc)
	feedSvc := feed.NewService(st, cache.New(cfg.RedisURL), familyauth.NewStub())
	feedHandler := NewFeedHandler(feedSvc)
	engagementSvc := engagement.NewService(st, auditclient.NewStub(), familyauth.NewStub(), hub)
	engagementHandler := NewEngagementHandler(engagementSvc)
	wsHandler := wshandler.NewFeedHandler(hub)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.FamilyContext)
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

	r.Post("/v1/posts", postHandler.Create)
	r.Delete("/v1/posts/{postId}", postHandler.Delete)
	r.Get("/v1/feeds/family", feedHandler.ListFamily)

	r.Post("/v1/posts/{postId}/likes", engagementHandler.Like)
	r.Delete("/v1/posts/{postId}/likes", engagementHandler.Unlike)
	r.Post("/v1/posts/{postId}/comments", engagementHandler.CreateComment)
	r.Delete("/v1/posts/{postId}/comments/{commentId}", engagementHandler.DeleteComment)

	r.Get("/v1/ws/feed", wsHandler.ServeHTTP)

	return r
}

// StartBackgroundJobs launches T5.5 OSS cleanup worker and reconciliation cron stubs.
func StartBackgroundJobs(ctx context.Context, cfg *config.Config, media mediaclient.Client) {
	if cfg == nil {
		cfg = &config.Config{}
	}
	stub, ok := media.(*mediaclient.Stub)
	if !ok {
		stub = mediaclient.NewStub()
	}
	if cfg.OSSCleanupWorkerEnabled {
		mediaclient.NewWorkerStub(stub, cfg.OSSCleanupWorkerInterval).Start(ctx)
	}
	if cfg.OSSReconcileCronEnabled {
		reconciliation.NewCron(
			reconciliation.NewService(stub, cfg.OSSReconcileStaleAfter),
			cfg.OSSReconcileCronInterval,
		).Start(ctx)
	}
}
