package grpc

import (
	"context"
	"testing"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

func TestSyncAuditRPC(t *testing.T) {
	mem := store.NewMemoryStore()
	rpc := NewAuditRPCServer(audit.NewService(mem, nil))
	ctx := context.Background()

	resp, err := rpc.SyncAudit(ctx, &SyncAuditRequest{
		Kind:      string(model.AuditKindInput),
		TargetRef: "tsk_rpc",
		Region:    "cn",
		Text:      "demo",
	})
	if err != nil {
		t.Fatalf("SyncAudit: %v", err)
	}
	if resp.Status != string(model.AuditStatusPassed) || resp.JobID == "" {
		t.Fatalf("unexpected response: %+v", resp)
	}
}

func TestSubmitAppealRPC(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := audit.NewService(mem, rejectVendor{})
	rpc := NewAuditRPCServer(svc)
	ctx := context.Background()

	syncResp, err := rpc.SyncAudit(ctx, &SyncAuditRequest{
		Kind:      string(model.AuditKindOutput),
		TargetRef: "tsk_rpc_appeal",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("SyncAudit: %v", err)
	}

	appealResp, err := rpc.SubmitAppeal(ctx, &SubmitAppealRequest{
		AuditJobID: syncResp.JobID,
		UserID:     "usr_rpc",
		Reason:     "误判",
	})
	if err != nil {
		t.Fatalf("SubmitAppeal: %v", err)
	}
	if appealResp.Status != string(model.AppealStatusPending) || appealResp.AppealID == "" {
		t.Fatalf("unexpected appeal response: %+v", appealResp)
	}
}

func TestSubmitAppealRPCByTargetRef(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := audit.NewService(mem, rejectVendor{})
	rpc := NewAuditRPCServer(svc)
	ctx := context.Background()

	_, err := rpc.SyncAudit(ctx, &SyncAuditRequest{
		Kind:      string(model.AuditKindOutput),
		TargetRef: "tsk_rpc_target_ref",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("SyncAudit: %v", err)
	}

	appealResp, err := rpc.SubmitAppeal(ctx, &SubmitAppealRequest{
		TargetRef: "tsk_rpc_target_ref",
		UserID:    "usr_rpc_target",
		Reason:    "误判",
	})
	if err != nil {
		t.Fatalf("SubmitAppeal by targetRef: %v", err)
	}
	if appealResp.Status != string(model.AppealStatusPending) || appealResp.AppealID == "" {
		t.Fatalf("unexpected appeal response: %+v", appealResp)
	}
}

type rejectVendor struct{}

func (rejectVendor) Audit(_ context.Context, _ audit.VendorRequest) (bool, []string, error) {
	return false, []string{"policy_violation"}, nil
}
