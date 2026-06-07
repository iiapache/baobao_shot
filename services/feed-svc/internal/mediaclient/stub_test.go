package mediaclient

import (
	"context"
	"testing"
)

func TestStubEnqueueDeletes(t *testing.T) {
	stub := NewStub()
	jobs, err := stub.EnqueueDeletes(context.Background(), []DeleteRequest{
		{PostID: "pst_1", ObjectKey: "family/fam_1/post/1.heic", Region: "cn"},
		{PostID: "pst_1", ObjectKey: "family/fam_1/post/thumb.jpg", Region: "cn"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(jobs) != 2 {
		t.Fatalf("jobs = %d, want 2", len(jobs))
	}
	if stub.PendingCount() != 2 {
		t.Fatalf("pending = %d", stub.PendingCount())
	}
}

func TestStubDispatchAndConfirm(t *testing.T) {
	stub := NewStub()
	if _, err := stub.EnqueueDeletes(context.Background(), []DeleteRequest{
		{PostID: "pst_2", ObjectKey: "family/fam_1/post/2.heic", Region: "cn"},
	}); err != nil {
		t.Fatal(err)
	}

	if n := stub.DispatchPending(0); n != 1 {
		t.Fatalf("dispatched = %d", n)
	}
	if stub.PendingCount() != 0 {
		t.Fatalf("pending after dispatch = %d", stub.PendingCount())
	}
	if n := stub.ConfirmDispatched(0); n != 1 {
		t.Fatalf("confirmed = %d", n)
	}
}

func TestWorkerStubRunOnce(t *testing.T) {
	stub := NewStub()
	if _, err := stub.EnqueueDeletes(context.Background(), []DeleteRequest{
		{PostID: "pst_3", ObjectKey: "family/fam_1/post/3.heic", Region: "cn"},
	}); err != nil {
		t.Fatal(err)
	}
	worker := NewWorkerStub(stub, 0)
	if n := worker.RunOnce(); n != 1 {
		t.Fatalf("worker dispatched = %d", n)
	}
}
