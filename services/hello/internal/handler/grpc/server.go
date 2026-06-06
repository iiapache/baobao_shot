package grpc

import (
	"context"
	"log/slog"
	"net"

	"github.com/baobao/hello/internal/config"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

type PingServer struct {
	serviceName string
}

func (s *PingServer) Ping(_ context.Context, _ *struct{}) (*PingResponse, error) {
	return &PingResponse{Message: "pong from " + s.serviceName}, nil
}

type PingResponse struct {
	Message string
}

func NewServer(cfg *config.Config) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	_ = &PingServer{serviceName: cfg.ServiceName}

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

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
