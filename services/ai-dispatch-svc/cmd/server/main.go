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

	"github.com/baobao/ai-dispatch-svc/internal/adapter/osconfig"
	"github.com/baobao/ai-dispatch-svc/internal/auditclient"
	"github.com/baobao/ai-dispatch-svc/internal/auth"
	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"github.com/baobao/ai-dispatch-svc/internal/costmetering"
	"github.com/baobao/ai-dispatch-svc/internal/creditclient"
	"github.com/baobao/ai-dispatch-svc/internal/filing"
	grpchandler "github.com/baobao/ai-dispatch-svc/internal/handler/grpc"
	"github.com/baobao/ai-dispatch-svc/internal/handler/rest"
	wshandler "github.com/baobao/ai-dispatch-svc/internal/handler/ws"
	"github.com/baobao/ai-dispatch-svc/internal/kafka"
	"github.com/baobao/ai-dispatch-svc/internal/middleware"
	"github.com/baobao/ai-dispatch-svc/internal/plays"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"github.com/baobao/ai-dispatch-svc/internal/worker"
	"github.com/baobao/ai-dispatch-svc/internal/ws"
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

	taskStore, err := store.NewTaskStore(cfg)
	if err != nil {
		return fmt.Errorf("init store: %w", err)
	}
	defer func() { _ = taskStore.Close(context.Background()) }()

	costStore, err := costmetering.NewStore(cfg)
	if err != nil {
		return fmt.Errorf("init cost metering store: %w", err)
	}
	defer func() { _ = costStore.Close(context.Background()) }()
	costSvc := costmetering.NewService(costStore)

	kafkaConsumer := kafka.NewStubConsumer()
	dispatchProducer := kafka.NewDispatchingProducer(kafka.NewStubProducer(), kafkaConsumer)
	producer := kafka.Producer(dispatchProducer)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var flagClient configclient.Client = configclient.NewStub(nil)
	if cfg.ConfigSvcURL != "" {
		flagClient = configclient.NewHTTPClient(cfg.ConfigSvcURL)
		slog.Info("config-svc client enabled", "url", cfg.ConfigSvcURL)
	}

	filingStore, err := filing.LoadAtStartup(ctx, filing.LoadOptions{
		ConfigPath:   cfg.AlgorithmFilingPath,
		Environment:  cfg.Environment,
		ConfigClient: flagClient,
	})
	if err != nil {
		return fmt.Errorf("load algorithm filings: %w", err)
	}
	filingStore.LogBindings()

	var workerPool *worker.Pool
	if cfg.WorkerEnabled {
		var creditClient worker.CreditClient = creditclient.NewStub()
		if cfg.CreditSvcGRPCAddr != "" {
			grpcCredit, err := creditclient.NewGRPCClient(cfg.CreditSvcGRPCAddr)
			if err != nil {
				return fmt.Errorf("init credit client: %w", err)
			}
			defer func() { _ = grpcCredit.Close() }()
			creditClient = grpcCredit
			slog.Info("credit-sub-ad-svc client enabled", "addr", cfg.CreditSvcGRPCAddr)
		}
		adapters := osconfig.EnrichAdapters(worker.DefaultDevAdapters(), ctx, flagClient)
		modelRouter := worker.BuildDevRouter(adapters, filingStore.Bindings())
		processor := worker.NewProcessor(taskStore, modelRouter, creditClient,
			worker.WithFilings(filingStore.Bindings()),
			worker.WithCostMetering(costSvc),
		)
		workerPool = worker.NewPool(cfg.WorkerPoolSize, processor)
		workerPool.Start(ctx)

		bridge := kafka.NewWorkerBridge(kafkaConsumer, workerPool.Submit)
		if err := bridge.Start(); err != nil {
			return fmt.Errorf("start worker bridge: %w", err)
		}
		defer func() { _ = bridge.Stop() }()
		slog.Info("worker pool started", "size", workerPool.Size())
	}
	if cfg.CostMeteringCronEnabled {
		costmetering.NewCron(costSvc, 7*24*time.Hour).Start(ctx)
		slog.Info("cost metering weekly cron enabled")
	}
	if cfg.KafkaEnabled {
		slog.Info("kafka stub enabled", "brokers", cfg.KafkaBrokers)
	}

	shutdownTracing, err := middleware.InitTracing(ctx, cfg)
	if err != nil {
		return fmt.Errorf("init tracing: %w", err)
	}
	defer func() { _ = shutdownTracing(context.Background()) }()

	wsHub := ws.NewHub(taskStore, ws.Config{
		PingInterval: time.Duration(cfg.WSPingIntervalSecs) * time.Second,
		PongTimeout:  time.Duration(cfg.WSPongTimeoutSecs) * time.Second,
	})
	go wsHub.Run(ctx)

	wsHandler := wshandler.NewHandler(wsHub, auth.NewValidator(cfg.JWTSigningSecret))

	grpcCtx, cancelGRPC := context.WithCancel(ctx)
	defer cancelGRPC()
	go func() {
		if err := grpchandler.ListenAndServe(grpcCtx, cfg, taskStore); err != nil {
			slog.Error("gRPC server error", "error", err)
		}
	}()

	_ = producer

	manifest, err := plays.LoadManifest()
	if err != nil {
		return fmt.Errorf("load plays manifest: %w", err)
	}
	playCatalog := plays.NewCatalogWithFilings(manifest, flagClient, filingStore)

	var auditClient auditclient.Client = auditclient.NewStub()
	if cfg.AuditSvcURL != "" {
		auditClient = auditclient.NewHTTPClient(cfg.AuditSvcURL)
		slog.Info("audit-svc client enabled", "url", cfg.AuditSvcURL)
	}

	handler := rest.NewRouter(cfg, rest.RouterDeps{
		WSHandler:    wsHandler,
		PlayCatalog:  playCatalog,
		TaskStore:    taskStore,
		AuditClient:  auditClient,
		CostMetering: costSvc,
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
		port = "8004"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/health", port))
	if err != nil || resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
