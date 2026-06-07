package upload

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/model"
	"github.com/baobao/media-svc/internal/store"
)

func testService(t *testing.T) (*Service, *store.MemoryUploadStore) {
	t.Helper()
	cfg := &config.Config{
		ServiceName:   "media-svc-test",
		STSTTLSeconds: 600,
		OSSBucket:     "baby-camera-cn",
		OSSEndpoint:   "https://oss-cn-hangzhou.aliyuncs.com",
	}
	mem := store.NewMemoryUploadStore()
	svc := NewService(cfg, mem, &MockSTSProvider{})
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixed }
	svc.newID = func() string { return "upl_test001" }
	return svc, mem
}

func TestInitAIInput(t *testing.T) {
	svc, mem := testService(t)

	out, err := svc.Init(context.Background(), InitInput{
		UserID:  "usr_ai",
		Region:  "cn",
		Purpose: model.PurposeAIInput,
		Items: []InitItemInput{{
			ClientRef: "c1",
			Kind:      "image",
			Mime:      "image/heic",
			Size:      2400000,
			SHA256:    "abc123",
		}},
	})
	if err != nil {
		t.Fatalf("Init() error = %v", err)
	}
	if out.UploadID != "upl_test001" {
		t.Fatalf("UploadID = %q", out.UploadID)
	}
	if out.STS.AccessKeyID == "" || out.STS.SecurityToken == "" {
		t.Fatal("expected STS credentials")
	}
	if len(out.Items) != 1 {
		t.Fatalf("items len = %d", len(out.Items))
	}
	item := out.Items[0]
	if item.ExpiresIn != 600 {
		t.Fatalf("ExpiresIn = %d, want 600", item.ExpiresIn)
	}
	if item.Method != "PUT" {
		t.Fatalf("Method = %q, want PUT", item.Method)
	}
	if item.ObjectKey == "" || item.UploadURL == "" {
		t.Fatal("expected objectKey and uploadUrl")
	}
	if got := item.ObjectKey; got[:7] != "ai-tmp/" {
		t.Fatalf("objectKey = %q, want ai-tmp prefix", got)
	}

	session, err := mem.GetSession(context.Background(), out.UploadID)
	if err != nil {
		t.Fatalf("GetSession() error = %v", err)
	}
	if session.Purpose != model.PurposeAIInput {
		t.Fatalf("purpose = %q", session.Purpose)
	}
}

func TestInitPostItemRequiresFamilyID(t *testing.T) {
	svc, _ := testService(t)
	_, err := svc.Init(context.Background(), InitInput{
		UserID:  "usr_post",
		Region:  "cn",
		Purpose: model.PurposePostItem,
		Items:   []InitItemInput{{ClientRef: "photo-1", Mime: "image/jpeg"}},
	})
	if err == nil {
		t.Fatal("expected error for missing familyId")
	}
}

func TestInitPostItemObjectKey(t *testing.T) {
	svc, _ := testService(t)
	out, err := svc.Init(context.Background(), InitInput{
		UserID:   "usr_post",
		Region:   "cn",
		Purpose:  model.PurposePostItem,
		FamilyID: "fam_01",
		Items:    []InitItemInput{{ClientRef: "photo-1", Mime: "image/jpeg"}},
	})
	if err != nil {
		t.Fatalf("Init() error = %v", err)
	}
	if out.Items[0].ObjectKey[:7] != "family/" {
		t.Fatalf("objectKey = %q, want family/ prefix", out.Items[0].ObjectKey)
	}
}

func TestCompleteFlow(t *testing.T) {
	svc, mem := testService(t)
	initOut, err := svc.Init(context.Background(), InitInput{
		UserID:   "usr_complete",
		Region:   "cn",
		Purpose:  model.PurposePostItem,
		FamilyID: "fam_01",
		Items:    []InitItemInput{{ClientRef: "photo-1", Mime: "image/jpeg", Size: 1024, SHA256: "deadbeef"}},
	})
	if err != nil {
		t.Fatalf("Init() error = %v", err)
	}

	completeOut, err := svc.Complete(context.Background(), CompleteInput{
		UserID:   "usr_complete",
		UploadID: initOut.UploadID,
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if completeOut.Status != "completed" {
		t.Fatalf("status = %q", completeOut.Status)
	}
	if len(completeOut.Items) != 1 {
		t.Fatalf("items len = %d", len(completeOut.Items))
	}

	session, err := mem.GetSession(context.Background(), initOut.UploadID)
	if err != nil {
		t.Fatalf("GetSession() error = %v", err)
	}
	if session.Status != model.UploadStatusCompleted {
		t.Fatalf("session status = %q", session.Status)
	}
}

func TestCompleteForbiddenForOtherUser(t *testing.T) {
	svc, _ := testService(t)
	initOut, err := svc.Init(context.Background(), InitInput{
		UserID:  "usr_owner",
		Region:  "cn",
		Purpose: model.PurposeAIInput,
		Items:   []InitItemInput{{ClientRef: "c1", Mime: "image/png"}},
	})
	if err != nil {
		t.Fatalf("Init() error = %v", err)
	}
	_, err = svc.Complete(context.Background(), CompleteInput{
		UserID:   "usr_other",
		UploadID: initOut.UploadID,
	})
	if err == nil {
		t.Fatal("expected forbidden error")
	}
}
