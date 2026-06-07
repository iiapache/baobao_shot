package grpc_test

import (
	"context"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	grpchandler "github.com/baobao/credit-sub-ad-svc/internal/handler/grpc"
	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	creditv1 "github.com/baobao/gen/baobao/credit/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func newTestCreditServer(t *testing.T) *grpchandler.CreditServer {
	t.Helper()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	if _, err := ledger.Grant(context.Background(), "usr_1", 100, "bootstrap", "usr_1"); err != nil {
		t.Fatalf("Grant() error = %v", err)
	}
	saga := credit.NewSagaService(st, idempotency.NewMemoryStore())
	return grpchandler.NewCreditServer(ledger, saga)
}

func TestCreditServer_HoldIdempotent(t *testing.T) {
	srv := newTestCreditServer(t)
	ctx := context.Background()

	req := &creditv1.HoldRequest{UserId: "usr_1", AiTaskId: "tsk_1", Amount: 8}
	first, err := srv.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}
	second, err := srv.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() duplicate error = %v", err)
	}
	if first.HoldId != second.HoldId || !second.Duplicate {
		t.Fatalf("duplicate hold = %+v, want holdId=%s duplicate=true", second, first.HoldId)
	}
}

func TestCreditServer_CommitThenReleaseBlocked(t *testing.T) {
	srv := newTestCreditServer(t)
	ctx := context.Background()

	hold, err := srv.Hold(ctx, &creditv1.HoldRequest{
		UserId: "usr_1", AiTaskId: "tsk_ok", Amount: 8,
	})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	if _, err := srv.Commit(ctx, &creditv1.CommitRequest{
		HoldId: hold.HoldId, AiTaskId: "tsk_ok",
	}); err != nil {
		t.Fatalf("Commit() error = %v", err)
	}
	if _, err := srv.Release(ctx, &creditv1.ReleaseRequest{
		HoldId: hold.HoldId, AiTaskId: "tsk_ok",
	}); err == nil {
		t.Fatal("Release() after commit should fail")
	} else if status.Code(err) != codes.FailedPrecondition {
		t.Fatalf("Release() code = %v, want FailedPrecondition", status.Code(err))
	}
}

func TestCreditServer_FailureRelease(t *testing.T) {
	srv := newTestCreditServer(t)
	ctx := context.Background()

	hold, err := srv.Hold(ctx, &creditv1.HoldRequest{
		UserId: "usr_1", AiTaskId: "tsk_fail", Amount: 8,
	})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	resp, err := srv.Release(ctx, &creditv1.ReleaseRequest{
		HoldId: hold.HoldId, AiTaskId: "tsk_fail",
	})
	if err != nil {
		t.Fatalf("Release() error = %v", err)
	}
	if resp.Duplicate {
		t.Fatal("first release should not be duplicate")
	}

	dup, err := srv.Release(ctx, &creditv1.ReleaseRequest{
		HoldId: hold.HoldId, AiTaskId: "tsk_fail",
	})
	if err != nil {
		t.Fatalf("Release() duplicate error = %v", err)
	}
	if !dup.Duplicate {
		t.Fatal("second release should be duplicate")
	}
}
