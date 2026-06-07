package creditclient_test

import (
	"context"
	"errors"
	"testing"

	"github.com/baobao/ai-dispatch-svc/internal/creditclient"
)

func TestStub_HoldIdempotent(t *testing.T) {
	stub := creditclient.NewStub()
	ctx := context.Background()

	req := creditclient.HoldRequest{
		UserID: "usr_1",
		TaskID: "tsk_1",
		Amount: 8,
	}

	first, err := stub.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}
	if first.HoldID == "" || first.Duplicate {
		t.Fatalf("first hold = %+v", first)
	}

	second, err := stub.Hold(ctx, req)
	if err != nil {
		t.Fatalf("Hold() duplicate error = %v", err)
	}
	if !second.Duplicate || second.HoldID != first.HoldID {
		t.Fatalf("duplicate hold = %+v, want holdId=%s duplicate=true", second, first.HoldID)
	}
	if len(stub.Held()) != 1 {
		t.Fatalf("held calls = %d, want 1", len(stub.Held()))
	}
}

func TestStub_CommitSuccess(t *testing.T) {
	stub := creditclient.NewStub()
	ctx := context.Background()

	hold, err := stub.Hold(ctx, creditclient.HoldRequest{
		UserID: "usr_1", TaskID: "tsk_ok", Amount: 8,
	})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	if err := stub.Commit(ctx, creditclient.SettleRequest{
		HoldID: hold.HoldID, TaskID: "tsk_ok",
	}); err != nil {
		t.Fatalf("Commit() error = %v", err)
	}
	if len(stub.Committed()) != 1 {
		t.Fatalf("committed = %d, want 1", len(stub.Committed()))
	}
	if len(stub.Released()) != 0 {
		t.Fatal("release should not run on success")
	}

	if err := stub.Commit(ctx, creditclient.SettleRequest{
		HoldID: hold.HoldID, TaskID: "tsk_ok",
	}); err != nil {
		t.Fatalf("Commit() duplicate error = %v", err)
	}
	if len(stub.Committed()) != 1 {
		t.Fatalf("committed after duplicate = %d, want 1", len(stub.Committed()))
	}
}

func TestStub_FailureRelease(t *testing.T) {
	stub := creditclient.NewStub()
	ctx := context.Background()

	hold, err := stub.Hold(ctx, creditclient.HoldRequest{
		UserID: "usr_1", TaskID: "tsk_fail", Amount: 8,
	})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	if err := stub.Release(ctx, creditclient.SettleRequest{
		HoldID: hold.HoldID, TaskID: "tsk_fail",
	}); err != nil {
		t.Fatalf("Release() error = %v", err)
	}
	if len(stub.Released()) != 1 {
		t.Fatalf("released = %d, want 1", len(stub.Released()))
	}

	if err := stub.Commit(ctx, creditclient.SettleRequest{
		HoldID: hold.HoldID, TaskID: "tsk_fail",
	}); !errors.Is(err, creditclient.ErrHoldSettled) {
		t.Fatalf("Commit() after release error = %v, want ErrHoldSettled", err)
	}
}

func TestStub_ReleaseIdempotent(t *testing.T) {
	stub := creditclient.NewStub()
	ctx := context.Background()

	hold, err := stub.Hold(ctx, creditclient.HoldRequest{
		UserID: "usr_1", TaskID: "tsk_refund", Amount: 8,
	})
	if err != nil {
		t.Fatalf("Hold() error = %v", err)
	}

	settle := creditclient.SettleRequest{HoldID: hold.HoldID, TaskID: "tsk_refund"}
	if err := stub.Release(ctx, settle); err != nil {
		t.Fatalf("Release() error = %v", err)
	}
	if err := stub.Release(ctx, settle); err != nil {
		t.Fatalf("Release() duplicate error = %v", err)
	}
	if len(stub.Released()) != 1 {
		t.Fatalf("released = %d, want 1", len(stub.Released()))
	}
}

func TestNormalizeIdempotencyKeys(t *testing.T) {
	hold := creditclient.NormalizeHold(creditclient.HoldRequest{TaskID: "tsk_1"})
	if hold.RefKind != creditclient.RefKindAITaskHold || hold.RefID != "tsk_1" {
		t.Fatalf("hold keys = %s/%s", hold.RefKind, hold.RefID)
	}
	commit := creditclient.NormalizeCommit(creditclient.SettleRequest{TaskID: "tsk_1"})
	if commit.RefKind != creditclient.RefKindAITaskCommit || commit.RefID != "tsk_1" {
		t.Fatalf("commit keys = %s/%s", commit.RefKind, commit.RefID)
	}
	release := creditclient.NormalizeRelease(creditclient.SettleRequest{TaskID: "tsk_1"})
	if release.RefKind != creditclient.RefKindAITaskRelease || release.RefID != "tsk_1" {
		t.Fatalf("release keys = %s/%s", release.RefKind, release.RefID)
	}
}
