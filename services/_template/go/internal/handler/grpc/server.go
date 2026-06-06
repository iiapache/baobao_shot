package grpc

import (
	"context"
	"log/slog"
	"net"

	"github.com/baobao/template/internal/config"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

// PingServer is a placeholder gRPC service until protobuf codegen is wired.
type PingServer struct {
	serviceName string
}

// Ping returns a simple pong message for smoke tests.
func (s *PingServer) Ping(_ context.Context, _ *struct{}) (*PingResponse, error) {
	return &PingResponse{Message: "pong from " + s.serviceName}, nil
}

// PingResponse mirrors tools/protobuf proto/baobao/common/v1/ping.proto.
type PingResponse struct {
	Message string
}

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	// Placeholder: register generated PingService after `make proto`
	_ = &PingServer{serviceName: cfg.ServiceName}

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg)
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
