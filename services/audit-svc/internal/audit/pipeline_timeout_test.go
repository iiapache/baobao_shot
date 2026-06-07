package audit

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/baobao/audit-svc/internal/audit/aliyun"
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

func TestInputPipeline_VendorTimeout(t *testing.T) {
	mem := store.NewMemoryStore()
	vendor := aliyunVendor{inner: aliyun.NewContentSecurityAdapter(aliyun.Config{
		MockMode:  true,
		MockDelay: 5 * time.Second,
	})}
	pipeline := NewInputPipeline(mem, vendor)
	ctx := context.Background()

	_, err := pipeline.SyncAudit(ctx, SyncRequest{
		TargetRef: "tsk_timeout",
		Region:    "cn",
		MediaType: "text",
		Text:      "hello",
	})
	if !errors.Is(err, ErrVendorTimeout) {
		t.Fatalf("error = %v, want ErrVendorTimeout", err)
	}
}

func TestOutputPipeline_VendorTimeout(t *testing.T) {
	mem := store.NewMemoryStore()
	vendor := aliyunVendor{inner: aliyun.NewContentSecurityAdapter(aliyun.Config{
		MockMode:  true,
		MockDelay: 8 * time.Second,
	})}
	pipeline := NewOutputPipeline(mem, vendor)
	ctx := context.Background()

	_, err := pipeline.SyncAudit(ctx, SyncRequest{
		TargetRef: "tsk_timeout",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "ai-out/fam_1/out.jpg",
	})
	if !errors.Is(err, ErrVendorTimeout) {
		t.Fatalf("error = %v, want ErrVendorTimeout", err)
	}
}

func TestCNVendorThreePipelines(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem, aliyunVendor{inner: aliyun.NewContentSecurityAdapter(aliyun.Config{MockMode: true})})
	ctx := context.Background()

	for _, kind := range []model.AuditKind{model.AuditKindInput, model.AuditKindOutput, model.AuditKindUGC} {
		job, err := svc.SyncAudit(ctx, kind, SyncRequest{
			TargetRef: "tsk_cn_pass",
			Region:    "cn",
			Text:      "正常内容",
		})
		if err != nil {
			t.Fatalf("%s sync: %v", kind, err)
		}
		if job.Status != model.AuditStatusPassed {
			t.Fatalf("%s status = %s, want passed", kind, job.Status)
		}
		if job.Vendor != aliyun.VendorName {
			t.Fatalf("%s vendor = %q, want %q", kind, job.Vendor, aliyun.VendorName)
		}
	}

	rejected, err := svc.SyncAudit(ctx, model.AuditKindInput, SyncRequest{
		TargetRef: "tsk_cn_reject",
		Region:    "cn",
		Text:      "reject_spam",
	})
	if err != nil {
		t.Fatalf("reject sync: %v", err)
	}
	if rejected.Status != model.AuditStatusRejected {
		t.Fatalf("status = %s, want rejected", rejected.Status)
	}
	if len(rejected.Reasons) == 0 {
		t.Fatal("expected reject reasons")
	}
}
