package grpc

import (
	"context"
	"log/slog"
	"net"

	feedv1 "github.com/baobao/gen/baobao/feed/v1"
	"github.com/baobao/feed-svc/internal/config"
	"github.com/baobao/feed-svc/internal/store"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

// FeedServer implements the generated FeedService gRPC API (T5.1 placeholder).
type FeedServer struct {
	feedv1.UnimplementedFeedServiceServer
	store store.Store
}

// NewFeedServer creates a FeedService handler backed by the store.
func NewFeedServer(st store.Store) *FeedServer {
	return &FeedServer{store: st}
}

// GetPost returns basic post status for internal callers.
func (s *FeedServer) GetPost(ctx context.Context, req *feedv1.GetPostRequest) (*feedv1.GetPostResponse, error) {
	if req == nil || req.PostId == "" {
		return nil, status.Error(codes.InvalidArgument, "post_id required")
	}
	post, err := s.store.GetPost(ctx, req.PostId)
	if err != nil {
		if err == store.ErrNotFound {
			return nil, status.Error(codes.NotFound, "post not found")
		}
		return nil, status.Error(codes.Internal, err.Error())
	}
	return &feedv1.GetPostResponse{PostId: post.ID, Status: post.Status}, nil
}

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config, st store.Store) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	feedv1.RegisterFeedServiceServer(srv, NewFeedServer(st))

	if cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config, st store.Store) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg, st)
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
