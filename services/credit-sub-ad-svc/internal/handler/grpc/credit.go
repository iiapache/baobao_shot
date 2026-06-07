package grpc

import (
	"context"
	"errors"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	creditv1 "github.com/baobao/gen/baobao/credit/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// CreditServer implements CreditSubAdService gRPC (T4.3).
type CreditServer struct {
	creditv1.UnimplementedCreditSubAdServiceServer
	ledger *credit.Service
	saga   *credit.SagaService
}

// NewCreditServer wires balance and saga handlers.
func NewCreditServer(ledger *credit.Service, saga *credit.SagaService) *CreditServer {
	return &CreditServer{ledger: ledger, saga: saga}
}

// GetBalance returns the current credit balance for a user.
func (s *CreditServer) GetBalance(ctx context.Context, req *creditv1.GetBalanceRequest) (*creditv1.GetBalanceResponse, error) {
	if req == nil || req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id required")
	}
	bal, err := s.ledger.GetBalance(ctx, req.UserId)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "get balance: %v", err)
	}
	return &creditv1.GetBalanceResponse{Balance: int32(bal.Balance)}, nil
}

// Hold reserves credits for an AI task.
func (s *CreditServer) Hold(ctx context.Context, req *creditv1.HoldRequest) (*creditv1.HoldResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "request required")
	}
	result, err := s.saga.Hold(ctx, credit.HoldInput{
		UserID:   req.UserId,
		AITaskID: req.AiTaskId,
		Amount:   int64(req.Amount),
		RefKind:  req.RefKind,
		RefID:    req.RefId,
	})
	if err != nil {
		return nil, mapSagaError(err)
	}
	return &creditv1.HoldResponse{
		HoldId:    result.HoldID,
		Duplicate: result.Duplicate,
	}, nil
}

// Commit finalizes a held reservation.
func (s *CreditServer) Commit(ctx context.Context, req *creditv1.CommitRequest) (*creditv1.CommitResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "request required")
	}
	result, err := s.saga.Commit(ctx, credit.SettleInput{
		HoldID:   req.HoldId,
		AITaskID: req.AiTaskId,
		RefKind:  req.RefKind,
		RefID:    req.RefId,
	})
	if err != nil {
		return nil, mapSagaError(err)
	}
	return &creditv1.CommitResponse{Duplicate: result.Duplicate}, nil
}

// Release refunds a held reservation.
func (s *CreditServer) Release(ctx context.Context, req *creditv1.ReleaseRequest) (*creditv1.ReleaseResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "request required")
	}
	result, err := s.saga.Release(ctx, credit.SettleInput{
		HoldID:   req.HoldId,
		AITaskID: req.AiTaskId,
		RefKind:  req.RefKind,
		RefID:    req.RefId,
	})
	if err != nil {
		return nil, mapSagaError(err)
	}
	return &creditv1.ReleaseResponse{Duplicate: result.Duplicate}, nil
}

func mapSagaError(err error) error {
	switch {
	case errors.Is(err, credit.ErrInvalidRequest):
		return status.Error(codes.InvalidArgument, err.Error())
	case errors.Is(err, credit.ErrInsufficientBalance):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, credit.ErrHoldNotFound):
		return status.Error(codes.NotFound, err.Error())
	case errors.Is(err, credit.ErrHoldSettled):
		return status.Error(codes.FailedPrecondition, err.Error())
	default:
		return status.Errorf(codes.Internal, "saga: %v", err)
	}
}
