package rest

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/audit-svc/internal/audit"
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

func TestAuditSyncREST(t *testing.T) {
	mem := store.NewMemoryStore()
	handler := NewAuditHandler(audit.NewService(mem, nil))
	r := chi.NewRouter()
	r.Post("/v1/audit/sync", handler.Sync)

	body, _ := json.Marshal(map[string]string{
		"kind":      string(model.AuditKindInput),
		"targetRef": "tsk_rest",
		"region":    "cn",
		"text":      "hello",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/audit/sync", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestSubmitAppealREST(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := audit.NewService(mem, rejectVendor{})
	handler := NewAuditHandler(svc)
	r := chi.NewRouter()
	r.Post("/v1/appeals", handler.SubmitAppeal)

	job, err := svc.SyncAudit(reqCtx(), model.AuditKindOutput, audit.SyncRequest{
		TargetRef: "tsk_rest_appeal",
		Region:    "cn",
	})
	if err != nil {
		t.Fatalf("sync: %v", err)
	}

	body, _ := json.Marshal(map[string]string{
		"auditJobId": job.ID,
		"userId":     "usr_rest",
		"reason":     "误判",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/appeals", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

type rejectVendor struct{}

func (rejectVendor) Audit(_ context.Context, _ audit.VendorRequest) (bool, []string, error) {
	return false, []string{"policy_violation"}, nil
}

func reqCtx() context.Context {
	return context.Background()
}
