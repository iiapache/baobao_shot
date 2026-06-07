package rest

import (
	"net/http"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
	"github.com/baobao/credit-sub-ad-svc/internal/appattest"
	"github.com/baobao/credit-sub-ad-svc/internal/config"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
	"github.com/baobao/credit-sub-ad-svc/internal/query"
	"github.com/baobao/credit-sub-ad-svc/internal/signin"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
	"github.com/go-chi/chi/v5"
)

// RouterDeps carries optional handlers wired into the HTTP router.
type RouterDeps struct {
	IAPVerify    *iap.Service
	Subscription *subscription.Service
	Query        *query.Service
	SignIn       *signin.Service
	AdReward     *adreward.Service
	AppAttest    appattest.Verifier
}

// NewRouter builds the REST API router with health probes.
func NewRouter(cfg *config.Config, st store.Store, deps RouterDeps) http.Handler {
	if cfg == nil {
		cfg = &config.Config{ServiceName: "credit-sub-ad-svc"}
	}
	if st == nil {
		st = store.NewMemoryStore()
	}

	health := NewHealthHandler(cfg.ServiceName)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth)

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	if deps.IAPVerify != nil {
		iapHandler := NewIAPVerifyHandler(deps.IAPVerify, deps.AppAttest)
		r.Post("/v1/credits/iap-verify", iapHandler.Verify)
	}
	if deps.Subscription != nil {
		subHandler := NewSubscriptionHandler(deps.Subscription, deps.AppAttest)
		r.Get("/v1/subscriptions/me", subHandler.GetMe)
		r.Post("/v1/subscriptions/iap-verify", subHandler.Verify)
	}
	if deps.Query != nil {
		creditsQuery := NewCreditsQueryHandler(deps.Query)
		subQuery := NewSubscriptionsQueryHandler(deps.Query)
		r.Get("/v1/credits/balance", creditsQuery.GetBalance)
		r.Get("/v1/credits/transactions", creditsQuery.ListTransactions)
		r.Get("/v1/credits/rates", creditsQuery.GetRates)
		r.Get("/v1/subscriptions/products", subQuery.ListProducts)
	}
	if deps.SignIn != nil {
		signInHandler := NewSignInHandler(deps.SignIn)
		r.Post("/v1/credits/sign-in", signInHandler.SignIn)
	}
	if deps.AdReward != nil {
		adRewardHandler := NewAdRewardHandler(deps.AdReward)
		r.Post("/v1/credits/ad-reward", adRewardHandler.ClientReport)
		r.Post("/v1/credits/ad-reward/pangle/callback", adRewardHandler.PangleCallback)
		r.Post("/v1/credits/ad-reward/gdt/callback", adRewardHandler.GDTCallback)
		r.Get("/v1/credits/ad-reward/admob/callback", adRewardHandler.AdMobCallback)
		r.Post("/v1/credits/ad-reward/admob/callback", adRewardHandler.AdMobCallback)
	}

	return r
}
