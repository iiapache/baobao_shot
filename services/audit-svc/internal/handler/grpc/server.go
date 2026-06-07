package grpc

import (
	"context"
	"log/slog"
	"net"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/config"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config, auditSvc *audit.Service) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	_ = NewAuditRPCServer(auditSvc)

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config, auditSvc *audit.Service) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg, auditSvc)
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
