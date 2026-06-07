package grpc

import (
	"context"
	"log/slog"
	"net"

	"github.com/baobao/credit-sub-ad-svc/internal/config"
	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	creditv1 "github.com/baobao/gen/baobao/credit/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

// Dependencies carries gRPC handler dependencies.
type Dependencies struct {
	Ledger *credit.Service
	Saga   *credit.SagaService
}

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config, deps Dependencies) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	creditv1.RegisterCreditSubAdServiceServer(srv, NewCreditServer(deps.Ledger, deps.Saga))

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config, deps Dependencies) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg, deps)
	slog.Info("gRPC listening", "addr", cfg.GRPCAddr())

	errCh := make(chan error, 1)
	go func() {
		errCh <- srv.Serve(lis)
	}()

	select {
	case <-ctx.Done():
		srv.GracefulStop()
		return nil
	case err := <-errCh:
		return err
	}
}
