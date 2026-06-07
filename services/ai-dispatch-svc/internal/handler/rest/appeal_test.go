package rest

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/auditclient"
	"github.com/baobao/ai-dispatch-svc/internal/config"
	"github.com/baobao/ai-dispatch-svc/internal/configclient"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/plays"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
	"github.com/baobao/ai-dispatch-svc/internal/store"
)

func newAppealTestRouter(t *testing.T, tasks store.TaskStore, audit auditclient.Client) http.Handler {
	t.Helper()
	m, err := plays.LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	cfg := &config.Config{
		ServiceName:      "ai-dispatch-svc-test",
		JWTSigningSecret: "dev-only-change-me",
	}
	catalog := plays.NewCatalog(m, configclient.NewStub(nil))
	return NewRouter(cfg, RouterDeps{
		PlayCatalog: catalog,
		TaskStore:   tasks,
		AuditClient: audit,
	})
}

func authAppealRequest(userID, taskID, reason string) *http.Request {
	body, _ := json.Marshal(map[string]string{"reason": reason})
	req := httptest.NewRequest(http.MethodPost, "/v1/ai/tasks/"+taskID+"/appeal", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev:"+userID)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Region", "cn")
	return req
}

func seedRejectedTask(t *testing.T, tasks store.TaskStore, taskID, userID string) {
	t.Helper()
	now := time.Now().UTC()
	err := tasks.Create(context.Background(), &model.Task{
		ID:     taskID,
		UserID: userID,
		Region: model.RegionCN,
		State:  string(statemachine.StateRejected),
		StateHistory: []model.StateHistoryEntry{
			{State: string(statemachine.StateRejected), At: now},
		},
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestAppealRejectedTask(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	auditStub := auditclient.NewStub()
	taskID := "tsk_appeal_ok"
	userID := "usr_appeal"
	seedRejectedTask(t, tasks, taskID, userID)
	auditStub.RegisterRejectedJob(taskID, "aud_reject_1")

	router := newAppealTestRouter(t, tasks, auditStub)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authAppealRequest(userID, taskID, "误判"))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if resp.Code != "OK" {
		t.Fatalf("code = %q, want OK", resp.Code)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	if data["taskId"] != taskID {
		t.Fatalf("taskId = %v", data["taskId"])
	}
	if data["state"] != string(statemachine.StateAppealed) {
		t.Fatalf("state = %v, want appealed", data["state"])
	}
	if data["appealId"] == "" {
		t.Fatal("appealId should not be empty")
	}

	got, err := tasks.GetByID(context.Background(), taskID)
	if err != nil {
		t.Fatal(err)
	}
	if got.State != string(statemachine.StateAppealed) {
		t.Fatalf("persisted state = %s, want appealed", got.State)
	}
}

func TestAppealRequiresRejectedState(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	auditStub := auditclient.NewStub()
	taskID := "tsk_running"
	userID := "usr_running"
	now := time.Now().UTC()
	if err := tasks.Create(context.Background(), &model.Task{
		ID: taskID, UserID: userID, Region: model.RegionCN,
		State: string(statemachine.StateRunning), CreatedAt: now, UpdatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}

	router := newAppealTestRouter(t, tasks, auditStub)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authAppealRequest(userID, taskID, "误判"))

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want 409; body=%s", rec.Code, rec.Body.String())
	}
}

func TestAppealRequiresAuth(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	router := newAppealTestRouter(t, tasks, auditclient.NewStub())
	rec := httptest.NewRecorder()
	req := authAppealRequest("usr_x", "tsk_x", "误判")
	req.Header.Del("Authorization")
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestAppealDuplicate(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	auditStub := auditclient.NewStub()
	taskID := "tsk_dup"
	userID := "usr_dup"
	seedRejectedTask(t, tasks, taskID, userID)
	auditStub.RegisterRejectedJob(taskID, "aud_dup")

	router := newAppealTestRouter(t, tasks, auditStub)
	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, authAppealRequest(userID, taskID, "误判"))
	if rec1.Code != http.StatusOK {
		t.Fatalf("first appeal status = %d", rec1.Code)
	}

	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, authAppealRequest(userID, taskID, "again"))
	if rec2.Code != http.StatusConflict {
		t.Fatalf("duplicate appeal status = %d, want 409; body=%s", rec2.Code, rec2.Body.String())
	}
}
