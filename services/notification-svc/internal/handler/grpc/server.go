package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"strings"

	notificationv1 "github.com/baobao/gen/baobao/notification/v1"
	"github.com/baobao/notification-svc/internal/apns"
	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/store"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

// NotificationServer implements the generated NotificationService gRPC API (T5.7 stub).
type NotificationServer struct {
	notificationv1.UnimplementedNotificationServiceServer
	store store.Store
	apns  *apns.Client
	topic string
}

// NewNotificationServer creates a NotificationService handler.
func NewNotificationServer(st store.Store, apnsClient *apns.Client, topic string) *NotificationServer {
	return &NotificationServer{store: st, apns: apnsClient, topic: topic}
}

// SendPush delivers a push to all registered devices for a user (stub via MockSender).
func (s *NotificationServer) SendPush(ctx context.Context, req *notificationv1.SendPushRequest) (*notificationv1.SendPushResponse, error) {
	if req == nil || strings.TrimSpace(req.UserId) == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	if s.apns == nil {
		return nil, status.Error(codes.FailedPrecondition, "apns client not configured")
	}

	tokens, err := s.store.ListDeviceTokensByUser(ctx, req.UserId)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	if len(tokens) == 0 {
		return nil, status.Error(codes.NotFound, "no device tokens")
	}

	var lastID string
	for _, dt := range tokens {
		result, err := s.apns.Send(ctx, apns.Region(dt.Region), apns.PushPayload{
			DeviceToken: dt.APNSToken,
			Title:       req.Title,
			Body:        req.Body,
			Priority:    10,
			Topic:       s.topic,
		})
		if err != nil && !result.TokenInvalid {
			return nil, status.Error(codes.Unavailable, err.Error())
		}
		if result.APNSID != "" {
			lastID = result.APNSID
		}
	}

	if lastID == "" {
		lastID = fmt.Sprintf("push_%s", req.UserId)
	}
	return &notificationv1.SendPushResponse{MessageId: lastID}, nil
}

// NewServer creates a gRPC server with health check and reflection (dev).
func NewServer(cfg *config.Config, st store.Store, apnsClient *apns.Client) *grpc.Server {
	srv := grpc.NewServer()

	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	topic := "app.babycamera"
	if cfg != nil && cfg.APNSTopic != "" {
		topic = cfg.APNSTopic
	}
	notificationv1.RegisterNotificationServiceServer(srv, NewNotificationServer(st, apnsClient, topic))

	if cfg != nil && cfg.Environment == "dev" {
		reflection.Register(srv)
	}

	return srv
}

// ListenAndServe starts the gRPC server on the configured port.
func ListenAndServe(ctx context.Context, cfg *config.Config, st store.Store, apnsClient *apns.Client) error {
	lis, err := net.Listen("tcp", cfg.GRPCAddr())
	if err != nil {
		return err
	}

	srv := NewServer(cfg, st, apnsClient)
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
