package reconciliation

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/feed-svc/internal/mediaclient"
)

func TestRunOnceNoIssuesWhenConfirmed(t *testing.T) {
	stub := mediaclient.NewStub()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	if _, err := stub.EnqueueDeletes(context.Background(), []mediaclient.DeleteRequest{
		{PostID: "pst_1", ObjectKey: "family/fam_1/post/1.heic", Region: "cn"},
	}); err != nil {
		t.Fatal(err)
	}
	stub.DispatchPending(0)
	stub.ConfirmDispatched(0)

	svc := NewService(stub, 24*time.Hour)
	svc.now = func() time.Time { return now }
	result, err := svc.RunOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if result.HasIssues() {
		t.Fatalf("result = %+v", result)
	}
	if result.Confirmed != 1 {
		t.Fatalf("confirmed = %d", result.Confirmed)
	}
}

func TestRunOnceFlagsStalePending(t *testing.T) {
	stub := mediaclient.NewStub()
	created := time.Date(2026, 6, 4, 12, 0, 0, 0, time.UTC)
	stub.SetNow(func() time.Time { return created })
	if _, err := stub.EnqueueDeletes(context.Background(), []mediaclient.DeleteRequest{
		{PostID: "pst_2", ObjectKey: "family/fam_1/post/2.heic", Region: "cn"},
	}); err != nil {
		t.Fatal(err)
	}

	svc := NewService(stub, 24*time.Hour)
	svc.now = func() time.Time { return created.Add(25 * time.Hour) }
	result, err := svc.RunOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasIssues() {
		t.Fatal("expected stale pending issue")
	}
	if result.Stale != 1 || len(result.Orphans) != 1 {
		t.Fatalf("result = %+v", result)
	}
}

func TestCronRunOnceNilSafe(t *testing.T) {
	cron := NewCron(nil, time.Minute)
	if _, err := cron.RunOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
}
