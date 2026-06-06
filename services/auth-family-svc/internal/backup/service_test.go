package backup

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestBindListUnbindProvider(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem)
	svc.now = func() time.Time { return time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC) }
	ctx := context.Background()
	userID := "usr_backup_bind"

	refresh := "refresh-token"
	expires := svc.now().Add(24 * time.Hour)
	accountID := "baidu-open-id"

	provider, err := svc.BindProvider(ctx, userID, BindInput{
		Kind:              model.BackupProviderKindBaiduPan,
		AccessToken:       "access-token",
		RefreshToken:      &refresh,
		ExpiresAt:         &expires,
		ProviderAccountID: &accountID,
		Metadata:          map[string]string{"scope": "basic"},
	})
	if err != nil {
		t.Fatalf("bind: %v", err)
	}
	if provider.AccessToken != "access-token" {
		t.Fatalf("token not persisted internally")
	}

	items, err := svc.ListProviders(ctx, userID)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(items) != 1 || items[0].Kind != model.BackupProviderKindBaiduPan {
		t.Fatalf("unexpected list: %+v", items)
	}

	updatedToken := "access-token-v2"
	_, err = svc.BindProvider(ctx, userID, BindInput{
		Kind:        model.BackupProviderKindBaiduPan,
		AccessToken: updatedToken,
	})
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	items, err = svc.ListProviders(ctx, userID)
	if err != nil {
		t.Fatalf("list after upsert: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("upsert should keep one provider, got %d", len(items))
	}
	stored, err := mem.ListBackupProviders(ctx, userID)
	if err != nil || stored[0].AccessToken != updatedToken {
		t.Fatalf("token not updated: %+v err=%v", stored, err)
	}

	if err := svc.UnbindProvider(ctx, userID, provider.ID); err != nil {
		t.Fatalf("unbind: %v", err)
	}
	items, err = svc.ListProviders(ctx, userID)
	if err != nil {
		t.Fatalf("list after unbind: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("expected empty list after unbind, got %+v", items)
	}
}

func TestBindValidation(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem)
	ctx := context.Background()

	if _, err := svc.BindProvider(ctx, "usr_validation", BindInput{Kind: "dropbox"}); err != ErrInvalidKind {
		t.Fatalf("invalid kind err = %v, want ErrInvalidKind", err)
	}
	if _, err := svc.BindProvider(ctx, "usr_validation", BindInput{Kind: model.BackupProviderKindBaiduPan}); err != ErrTokenRequired {
		t.Fatalf("missing token err = %v, want ErrTokenRequired", err)
	}
}

func TestReportStatusSuccessAndFailure(t *testing.T) {
	mem := store.NewMemoryStore()
	base := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc := NewService(mem)
	svc.now = func() time.Time { return base }
	ctx := context.Background()
	userID := "usr_backup_status"

	empty, err := svc.GetStatus(ctx, userID)
	if err != nil {
		t.Fatalf("get empty status: %v", err)
	}
	if empty.FailureCount != 0 {
		t.Fatalf("failureCount = %d, want 0", empty.FailureCount)
	}

	successAt := base.Add(-time.Hour)
	status, err := svc.ReportStatus(ctx, userID, ReportStatusInput{
		Success:     true,
		AttemptedAt: successAt,
	})
	if err != nil {
		t.Fatalf("report success: %v", err)
	}
	if status.FailureCount != 0 || status.LastSuccessAt == nil {
		t.Fatalf("unexpected success status: %+v", status)
	}

	errCode := "BACKUP_AUTH_REVOKED"
	failAt := base
	status, err = svc.ReportStatus(ctx, userID, ReportStatusInput{
		Success:     false,
		AttemptedAt: failAt,
		ErrorCode:   &errCode,
	})
	if err != nil {
		t.Fatalf("report failure: %v", err)
	}
	if status.FailureCount != 1 || status.LastErrorCode == nil || *status.LastErrorCode != errCode {
		t.Fatalf("unexpected failure status: %+v", status)
	}

	status, err = svc.ReportStatus(ctx, userID, ReportStatusInput{
		Success:     true,
		AttemptedAt: base.Add(time.Minute),
	})
	if err != nil {
		t.Fatalf("report recovery: %v", err)
	}
	if status.FailureCount != 0 || status.LastErrorCode != nil {
		t.Fatalf("success should reset failures: %+v", status)
	}
}

func TestUnbindNotFound(t *testing.T) {
	mem := store.NewMemoryStore()
	svc := NewService(mem)
	if err := svc.UnbindProvider(context.Background(), "usr_missing", "bkp_missing"); err != ErrNotFound {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}
