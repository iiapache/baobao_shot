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

	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/device"
	grpchandler "github.com/baobao/notification-svc/internal/handler/grpc"
	"github.com/baobao/notification-svc/internal/handler/rest"
	"github.com/baobao/notification-svc/internal/inbox"
	kafkahandler "github.com/baobao/notification-svc/internal/kafka"
	"github.com/baobao/notification-svc/internal/middleware"
	"github.com/baobao/notification-svc/internal/orchestrator"
	"github.com/baobao/notification-svc/internal/store"
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

	deviceSvc := device.NewService(st)
	apnsClient, err := apns.NewClient(apns.Config{
		Sandbox: cfg.APNSSandbox,
		Cleaner: deviceSvc,
	})
	if err != nil {
		return fmt.Errorf("init apns client: %w", err)
	}

	inboxSvc := inbox.NewService(st)
	pushOrch := orchestrator.NewService(st, inboxSvc, apnsClient, cfg.APNSTopic)
	kafkaConsumer := kafkahandler.NewConsumer(cfg, pushOrch)
	kafkaCtx, cancelKafka := context.WithCancel(ctx)
	defer cancelKafka()
	go func() {
		if err := kafkaConsumer.Start(kafkaCtx); err != nil {
			slog.Error("kafka consumer error", "error", err)
		}
	}()

	shutdownTracing, err := middleware.InitTracing(ctx, cfg)
	if err != nil {
		return fmt.Errorf("init tracing: %w", err)
	}
	defer func() { _ = shutdownTracing(context.Background()) }()

	grpcCtx, cancelGRPC := context.WithCancel(ctx)
	defer cancelGRPC()
	go func() {
		if err := grpchandler.ListenAndServe(grpcCtx, cfg, st, apnsClient); err != nil {
			slog.Error("gRPC server error", "error", err)
		}
	}()

	handler := rest.NewRouter(cfg, st, apnsClient)
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
		port = "8008"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/health", port))
	if err != nil || resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
