package idempotency_test

import (
	"context"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/idempotency"
)

func TestMemoryStore_HoldAndSettled(t *testing.T) {
	st := idempotency.NewMemoryStore()
	ctx := context.Background()

	if _, ok, err := st.GetHoldID(ctx, "ai_task_hold", "tsk_1"); err != nil || ok {
		t.Fatalf("GetHoldID() = ok=%v err=%v, want false", ok, err)
	}
	if err := st.SaveHoldID(ctx, "ai_task_hold", "tsk_1", "hld_1"); err != nil {
		t.Fatal(err)
	}
	holdID, ok, err := st.GetHoldID(ctx, "ai_task_hold", "tsk_1")
	if err != nil || !ok || holdID != "hld_1" {
		t.Fatalf("GetHoldID() = %q ok=%v err=%v", holdID, ok, err)
	}

	settled, err := st.IsSettled(ctx, "ai_task_commit", "tsk_1")
	if err != nil || settled {
		t.Fatalf("IsSettled() = %v err=%v, want false", settled, err)
	}
	if err := st.MarkSettled(ctx, "ai_task_commit", "tsk_1"); err != nil {
		t.Fatal(err)
	}
	settled, err = st.IsSettled(ctx, "ai_task_commit", "tsk_1")
	if err != nil || !settled {
		t.Fatalf("IsSettled() after mark = %v err=%v", settled, err)
	}
}
