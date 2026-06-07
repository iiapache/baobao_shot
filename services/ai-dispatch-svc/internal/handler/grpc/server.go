package grpc

import (
	"context"
	"log/slog"
	"net"

	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

// GetTaskRequest mirrors contracts/protobuf proto/baobao/ai/v1/ai_dispatch.proto.
type GetTaskRequest struct {
	TaskID string
}

// GetTaskResponse mirrors contracts/protobuf proto/baobao/ai/v1/ai_dispatch.proto.
type GetTaskResponse struct {
	TaskID string
	State  string
}

// AiDispatchServer is a placeholder until protobuf codegen is wired (T3.7+).
type AiDispatchServer struct {
	taskStore store.TaskStore
}

// GetTask returns task state by id (internal gRPC stub).
func (s *AiDispatchServer) GetTask(ctx context.Context, req *GetTaskRequest) (*GetTaskResponse, error) {
	if req == nil || req.TaskID == "" {
		return nil, status.Error(codes.InvalidArgument, "task_id required")
	}
	task, err := s.taskStore.GetByID(ctx, req.TaskID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "task not found")
	}
	return &GetTaskResponse{TaskID: task.ID, State: task.State}, nil
}

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config, taskStore store.TaskStore) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	_ = &AiDispatchServer{taskStore: taskStore}

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config, taskStore store.TaskStore) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg, taskStore)
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
