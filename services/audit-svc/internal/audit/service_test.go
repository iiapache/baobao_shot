package audit

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

type rejectVendor struct{}

func (rejectVendor) Audit(_ context.Context, _ VendorRequest) (bool, []string, error) {
	return false, []string{"policy_violation"}, nil
}

func TestSyncAuditThreePipelines(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, nil)
	ctx := context.Background()

	for _, kind := range []model.AuditKind{model.AuditKindInput, model.AuditKindOutput, model.AuditKindUGC} {
		job, err := svc.SyncAudit(ctx, kind, SyncRequest{
			TargetRef: "tsk_demo",
			Region:    "cn",
			Text:      "hello",
		})
		if err != nil {
			t.Fatalf("%s sync: %v", kind, err)
		}
		if job.Status != model.AuditStatusPassed {
			t.Fatalf("%s status = %s, want passed", kind, job.Status)
		}
		if job.CompletedAt == nil {
			t.Fatalf("%s missing completed_at", kind)
		}
	}
}

func TestSyncAuditRejected(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, rejectVendor{})
	ctx := context.Background()

	job, err := svc.SyncAudit(ctx, model.AuditKindInput, SyncRequest{
		TargetRef: "tsk_reject",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("sync: %v", err)
	}
	if job.Status != model.AuditStatusRejected {
		t.Fatalf("status = %s, want rejected", job.Status)
	}
	if len(job.Reasons) != 1 || job.Reasons[0] != "policy_violation" {
		t.Fatalf("reasons = %+v", job.Reasons)
	}
}

func TestSubmitAppeal(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, rejectVendor{})
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC) }
	svc.newID = func() string { return "apl_test" }
	ctx := context.Background()

	job, err := svc.SyncAudit(ctx, model.AuditKindOutput, SyncRequest{
		TargetRef: "tsk_appeal",
		Region:    "os",
	})
	if err != nil {
		t.Fatalf("sync: %v", err)
	}

	appeal, err := svc.SubmitAppeal(ctx, job.ID, "usr_demo", "误判")
	if err != nil {
		t.Fatalf("submit appeal: %v", err)
	}
	if appeal.Status != model.AppealStatusPending || appeal.AuditJobID != job.ID {
		t.Fatalf("unexpected appeal: %+v", appeal)
	}

	if _, err := svc.SubmitAppeal(ctx, job.ID, "usr_demo", "again"); !errors.Is(err, ErrAppealDuplicate) {
		t.Fatalf("expected duplicate appeal, got %v", err)
	}
}

func TestSubmitAppealForTask(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, rejectVendor{})
	ctx := context.Background()

	job, err := svc.SyncAudit(ctx, model.AuditKindOutput, SyncRequest{
		TargetRef: "tsk_task_appeal",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("sync: %v", err)
	}

	appeal, err := svc.SubmitAppealForTask(ctx, job.TargetRef, "usr_demo", "误判")
	if err != nil {
		t.Fatalf("submit appeal for task: %v", err)
	}
	if appeal.AuditJobID != job.ID || appeal.Status != model.AppealStatusPending {
		t.Fatalf("unexpected appeal: %+v", appeal)
	}

	if _, err := svc.SubmitAppealForTask(ctx, "tsk_missing", "usr_demo", "误判"); !errors.Is(err, ErrAuditJobNotFound) {
		t.Fatalf("expected ErrAuditJobNotFound, got %v", err)
	}
}

func TestSubmitAppealNotAllowed(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, nil)
	ctx := context.Background()

	job, err := svc.SyncAudit(ctx, model.AuditKindInput, SyncRequest{
		TargetRef: "tsk_ok",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("sync: %v", err)
	}
	if _, err := svc.SubmitAppeal(ctx, job.ID, "usr_demo", "误判"); !errors.Is(err, ErrAppealNotAllowed) {
		t.Fatalf("expected ErrAppealNotAllowed, got %v", err)
	}
}

func TestUGCAsyncFlow(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, nil)
	ctx := context.Background()

	job, err := svc.EnqueueUGCAsync(ctx, SyncRequest{
		TargetRef: "post_item_1",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/fam_1/pending/item.jpg",
	})
	if err != nil {
		t.Fatalf("enqueue: %v", err)
	}
	if job.Status != model.AuditStatusPending {
		t.Fatalf("status = %s, want pending", job.Status)
	}

	completed, err := svc.CompleteUGCAsync(ctx, job.ID, SyncRequest{
		TargetRef: job.TargetRef,
		Region:    job.Region,
		MediaType: "image",
		ObjectKey: "family/fam_1/pending/item.jpg",
	})
	if err != nil {
		t.Fatalf("complete: %v", err)
	}
	if completed.Status != model.AuditStatusPassed {
		t.Fatalf("status = %s, want passed", completed.Status)
	}
}
