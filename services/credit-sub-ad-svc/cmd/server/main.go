package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
	"github.com/baobao/credit-sub-ad-svc/internal/config"
	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	grpchandler "github.com/baobao/credit-sub-ad-svc/internal/handler/grpc"
	"github.com/baobao/credit-sub-ad-svc/internal/handler/rest"
	"github.com/baobao/credit-sub-ad-svc/internal/iap"
	"github.com/baobao/credit-sub-ad-svc/internal/iapevent"
	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
	kafkahandler "github.com/baobao/credit-sub-ad-svc/internal/kafka"
	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
	"github.com/baobao/credit-sub-ad-svc/internal/query"
	"github.com/baobao/credit-sub-ad-svc/internal/rates"
	"github.com/baobao/credit-sub-ad-svc/internal/reconciliation"
	"github.com/baobao/credit-sub-ad-svc/internal/signin"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(runHealthcheck())
	}

	if err := run(); err != nil {
		slog.Error("server exited", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	st, db, err := store.New(ctx, cfg)
	if err != nil {
		return fmt.Errorf("init store: %w", err)
	}
	if db != nil {
		defer db.Close()
	}

	shutdownTracing, err := middleware.InitTracing(ctx, cfg)
	if err != nil {
		return fmt.Errorf("init tracing: %w", err)
	}
	defer func() { _ = shutdownTracing(context.Background()) }()

	ledgerSvc := credit.NewService(st)
	sagaSvc := credit.NewSagaService(st, idempotency.New(cfg.RedisURL))
	grpcDeps := grpchandler.Dependencies{Ledger: ledgerSvc, Saga: sagaSvc}

	grpcCtx, cancelGRPC := context.WithCancel(ctx)
	defer cancelGRPC()
	go func() {
		if err := grpchandler.ListenAndServe(grpcCtx, cfg, grpcDeps); err != nil {
			slog.Error("gRPC server error", "error", err)
		}
	}()

	iapSvc := iap.NewService(st, ledgerSvc, iap.NewJWSVerifier(cfg.AppleIAPBundleID), iap.DefaultProductCatalog)
	subSvc := subscription.NewService(st, iap.NewJWSVerifier(cfg.AppleIAPBundleID), subscription.DefaultProductCatalog)
	ratesCatalog, err := rates.LoadCatalog()
	if err != nil {
		return fmt.Errorf("load rates catalog: %w", err)
	}
	querySvc := query.NewService(st, ledgerSvc, ratesCatalog)
	signInSvc := signin.NewService(st, ledgerSvc)
	adRewardSvc := adreward.NewService(
		st,
		ledgerSvc,
		adreward.NewRegistry(cfg.PangleSecurityKey, cfg.GDTSecretKey),
		adreward.Options{
			DailyLimit:  cfg.AdRewardDailyLimit,
			MinInterval: time.Duration(cfg.AdRewardMinIntervalSec) * time.Second,
		},
	)
	if cfg.SubscriptionCronEnabled {
		subscription.NewCron(subSvc, cfg.SubscriptionCronInterval).Start(ctx)
		slog.Info("subscription expiry cron enabled", "interval", cfg.SubscriptionCronInterval.String())
	}
	if cfg.ReconciliationCronEnabled {
		reconSvc := reconciliation.NewService(
			st,
			iap.DefaultProductCatalog,
			reconciliation.NewHTTPCostMeteringSource(cfg.AIDispatchCostMeteringURL),
		)
		reconciliation.NewCron(reconSvc, cfg.ReconciliationCronInterval).Start(ctx)
		slog.Info("credit reconciliation cron enabled", "interval", cfg.ReconciliationCronInterval.String())
	}

	iapEventHandler := iapevent.NewHandler(st, ledgerSvc, subSvc, iap.DefaultProductCatalog, subscription.DefaultProductCatalog)
	kafkaConsumer := kafkahandler.NewConsumer(cfg, iapEventHandler)
	kafkaCtx, cancelKafka := context.WithCancel(ctx)
	defer cancelKafka()
	go func() {
		if err := kafkaConsumer.Start(kafkaCtx); err != nil {
			slog.Error("kafka consumer error", "error", err)
		}
	}()

	handler := rest.NewRouter(cfg, st, rest.RouterDeps{
		IAPVerify:    iapSvc,
		Subscription: subSvc,
		Query:        querySvc,
		SignIn:       signInSvc,
		AdReward:     adRewardSvc,
	})
	httpServer := &http.Server{
		Addr:              cfg.HTTPAddr(),
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		slog.Info("HTTP listening", "addr", cfg.HTTPAddr(), "service", cfg.ServiceName)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("HTTP server error", "error", err)
		}
	}()

	<-ctx.Done()
	slog.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return httpServer.Shutdown(shutdownCtx)
}

func runHealthcheck() int {
	port := os.Getenv("HTTP_PORT")
	if port == "" {
		port = "8006"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/health", port))
	if err != nil || resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
