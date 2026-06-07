package auditclient

import (
	"context"
	"testing"
)

func TestStubTextRejectMarker(t *testing.T) {
	stub := NewStub()
	result, err := stub.AuditTextSync(context.Background(), TextAuditRequest{
		TargetRef: "pst_1",
		Region:    "cn",
		Text:      "包含 reject_spam 的广告",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Passed {
		t.Fatal("expected text reject")
	}
	if len(result.Reasons) == 0 {
		t.Fatal("expected reject reasons")
	}
}

func TestStubMediaAsyncPending(t *testing.T) {
	stub := NewStub()
	result, err := stub.EnqueueMediaAsync(context.Background(), MediaAuditRequest{
		TargetRef: "pst_1",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/fam_1/post/1.heic",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.JobID == "" {
		t.Fatal("expected job id")
	}
	if stub.PendingCount() != 1 {
		t.Fatalf("pending = %d", stub.PendingCount())
	}
}

func TestStubMediaCompleteReject(t *testing.T) {
	stub := NewStub()
	result, err := stub.EnqueueMediaAsync(context.Background(), MediaAuditRequest{
		TargetRef: "pst_2",
		Region:    "cn",
		MediaType: "image",
		ObjectKey: "family/fam_1/post/reject_porn.heic",
	})
	if err != nil {
		t.Fatal(err)
	}
	done := stub.CompleteMedia(result.JobID)
	if done.Passed {
		t.Fatal("expected media reject")
	}
}
