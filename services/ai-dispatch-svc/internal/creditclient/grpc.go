package creditclient

import (
	"context"
	"fmt"

	creditv1 "github.com/baobao/gen/baobao/credit/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
)

// GRPCClient calls credit-sub-ad-svc saga RPC (T3.14 / T4.3).
type GRPCClient struct {
	client creditv1.CreditSubAdServiceClient
	conn   *grpc.ClientConn
}

// NewGRPCClient dials credit-sub-ad-svc gRPC.
func NewGRPCClient(addr string) (*GRPCClient, error) {
	if addr == "" {
		return nil, fmt.Errorf("credit grpc addr required")
	}
	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("dial credit-sub-ad-svc: %w", err)
	}
	return &GRPCClient{
		client: creditv1.NewCreditSubAdServiceClient(conn),
		conn:   conn,
	}, nil
}

// Close releases the underlying connection.
func (c *GRPCClient) Close() error {
	if c.conn == nil {
		return nil
	}
	return c.conn.Close()
}

// Hold calls CreditSubAdService.Hold.
func (c *GRPCClient) Hold(ctx context.Context, req HoldRequest) (*HoldResponse, error) {
	req = NormalizeHold(req)
	if req.UserID == "" || req.TaskID == "" || req.Amount <= 0 {
		return nil, fmt.Errorf("%w: userId, taskId and positive amount required", ErrInvalidRequest)
	}
	resp, err := c.client.Hold(ctx, &creditv1.HoldRequest{
		UserId:   req.UserID,
		AiTaskId: req.TaskID,
		Amount:   req.Amount,
		RefKind:  req.RefKind,
		RefId:    req.RefID,
	})
	if err != nil {
		return nil, mapGRPCError(err)
	}
	return &HoldResponse{HoldID: resp.HoldId, Duplicate: resp.Duplicate}, nil
}

// Commit calls CreditSubAdService.Commit.
func (c *GRPCClient) Commit(ctx context.Context, req SettleRequest) error {
	req = NormalizeCommit(req)
	if req.HoldID == "" {
		return fmt.Errorf("%w: holdId required", ErrInvalidRequest)
	}
	resp, err := c.client.Commit(ctx, &creditv1.CommitRequest{
		HoldId:   req.HoldID,
		AiTaskId: req.TaskID,
		RefKind:  req.RefKind,
		RefId:    req.RefID,
	})
	if err != nil {
		return mapGRPCError(err)
	}
	if resp.Duplicate {
		return nil
	}
	return nil
}

// Release calls CreditSubAdService.Release.
func (c *GRPCClient) Release(ctx context.Context, req SettleRequest) error {
	req = NormalizeRelease(req)
	if req.HoldID == "" {
		return fmt.Errorf("%w: holdId required", ErrInvalidRequest)
	}
	resp, err := c.client.Release(ctx, &creditv1.ReleaseRequest{
		HoldId:   req.HoldID,
		AiTaskId: req.TaskID,
		RefKind:  req.RefKind,
		RefId:    req.RefID,
	})
	if err != nil {
		return mapGRPCError(err)
	}
	if resp.Duplicate {
		return nil
	}
	return nil
}

func mapGRPCError(err error) error {
	if err == nil {
		return nil
	}
	st, ok := status.FromError(err)
	if !ok {
		return err
	}
	switch st.Code() {
	case codes.InvalidArgument:
		return fmt.Errorf("%w: %s", ErrInvalidRequest, st.Message())
	case codes.NotFound:
		return ErrHoldNotFound
	case codes.FailedPrecondition:
		msg := st.Message()
		if msg == "insufficient credit balance" {
			return fmt.Errorf("%w: %s", ErrInvalidRequest, msg)
		}
		return ErrHoldSettled
	default:
		return err
	}
}
