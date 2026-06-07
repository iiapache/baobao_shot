package rest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/auditclient"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
	"github.com/baobao/ai-dispatch-svc/internal/store"
)

// Contract tests align handler responses with contracts/openapi (ApiResponse + aiAppealTask).

func TestContractAiAppealTaskResponseShape(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	auditStub := auditclient.NewStub()
	taskID := "tsk_contract_appeal"
	userID := "usr_contract_appeal"
	seedRejectedTask(t, tasks, taskID, userID)
	auditStub.RegisterRejectedJob(taskID, "aud_contract")

	router := newAppealTestRouter(t, tasks, auditStub)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authAppealRequest(userID, taskID, "误判"))

	if rec.Code != http.StatusOK {
		t.Fatalf("aiAppealTask status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"code", "requestId"} {
		if _, ok := raw[key]; !ok {
			t.Fatalf("aiAppealTask response missing OpenAPI required field %q", key)
		}
	}
	if string(raw["code"]) != `"OK"` {
		t.Fatalf("code = %s, want OK", raw["code"])
	}
}

func TestContractAiAppealTaskRequiresAuth(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	router := newAppealTestRouter(t, tasks, auditclient.NewStub())
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/ai/tasks/tsk_x/appeal", nil)
	req.Header.Set("X-Region", "cn")
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (OpenAPI bearerAuth)", rec.Code)
	}
}

func TestContractAiAppealTaskDataFields(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	auditStub := auditclient.NewStub()
	taskID := "tsk_contract_data"
	userID := "usr_contract_data"
	seedRejectedTask(t, tasks, taskID, userID)
	auditStub.RegisterRejectedJob(taskID, "aud_data")

	router := newAppealTestRouter(t, tasks, auditStub)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authAppealRequest(userID, taskID, "内容误判"))

	resp, err := decodeAPIResponse(rec.Body.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	data, ok := resp.Data.(map[string]any)
	if !ok {
		t.Fatal("data is not a map")
	}
	for _, key := range []string{"taskId", "state", "appealId"} {
		if _, ok := data[key]; !ok {
			t.Fatalf("appeal data missing field %q", key)
		}
	}
	if data["state"] != string(statemachine.StateAppealed) {
		t.Fatalf("state = %v, want appealed", data["state"])
	}
}

func TestContractAiAppealTaskRejectedOnly(t *testing.T) {
	tasks := store.NewMemoryTaskStore()
	taskID := "tsk_contract_not_rejected"
	userID := "usr_contract_not_rejected"
	now := time.Now().UTC()
	if err := tasks.Create(context.Background(), &model.Task{
		ID: taskID, UserID: userID, State: string(statemachine.StateSucceeded),
		CreatedAt: now, UpdatedAt: now,
	}); err != nil {
		t.Fatal(err)
	}

	router := newAppealTestRouter(t, tasks, auditclient.NewStub())
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, authAppealRequest(userID, taskID, "误判"))

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want 409 for non-rejected task", rec.Code)
	}
}
