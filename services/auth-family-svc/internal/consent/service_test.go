package consent

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/store"
)

func TestRecordChildDataConsent(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()

	user, err := mem.CreateUser(ctx, store.CreateUserInput{
		ID:       "usr_consent_test",
		AppleSub: "apple-consent",
		Region:   "cn",
		Nickname: "test",
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}

	svc := NewService(mem)
	fixed := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixed }

	record, err := svc.RecordChildDataConsent(ctx, user.ID, CurrentConsentVersion, true, "127.0.0.1", "dev-1")
	if err != nil {
		t.Fatalf("record consent: %v", err)
	}
	if record.Version != CurrentConsentVersion {
		t.Fatalf("version = %q, want %q", record.Version, CurrentConsentVersion)
	}
	if !record.AgreedAt.Equal(fixed) {
		t.Fatalf("agreedAt = %v, want %v", record.AgreedAt, fixed)
	}
	if record.IP != "127.0.0.1" || record.DeviceID != "dev-1" {
		t.Fatalf("unexpected audit fields: %+v", record)
	}

	has, err := svc.HasValidChildDataConsent(ctx, user.ID)
	if err != nil {
		t.Fatalf("has consent: %v", err)
	}
	if !has {
		t.Fatal("expected valid consent")
	}

	reloaded, err := mem.FindByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("find user: %v", err)
	}
	if reloaded.ChildDataConsentAt == nil || !reloaded.ChildDataConsentAt.Equal(fixed) {
		t.Fatalf("user consent timestamp not synced: %+v", reloaded.ChildDataConsentAt)
	}
}

func TestRecordChildDataConsentVersionMismatch(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_version", AppleSub: "apple-version", Region: "cn",
	})

	svc := NewService(mem)
	if _, err := svc.RecordChildDataConsent(ctx, user.ID, "old-version", true, "", ""); err != ErrVersionMismatch {
		t.Fatalf("err = %v, want ErrVersionMismatch", err)
	}
}

func TestRecordChildDataConsentNotAccepted(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_reject", AppleSub: "apple-reject", Region: "cn",
	})

	svc := NewService(mem)
	if _, err := svc.RecordChildDataConsent(ctx, user.ID, CurrentConsentVersion, false, "", ""); err != ErrNotAccepted {
		t.Fatalf("err = %v, want ErrNotAccepted", err)
	}
}

func TestHasValidChildDataConsentFalseForNewUser(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_new", AppleSub: "apple-new", Region: "cn",
	})

	svc := NewService(mem)
	has, err := svc.HasValidChildDataConsent(ctx, user.ID)
	if err != nil {
		t.Fatalf("has consent: %v", err)
	}
	if has {
		t.Fatal("new user should not have consent")
	}
}

func TestRecordChildDataConsentUpsert(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_upsert", AppleSub: "apple-upsert", Region: "cn",
	})

	svc := NewService(mem)
	first := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return first }
	if _, err := svc.RecordChildDataConsent(ctx, user.ID, CurrentConsentVersion, true, "1.1.1.1", "d1"); err != nil {
		t.Fatalf("first record: %v", err)
	}

	second := time.Date(2026, 6, 6, 0, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return second }
	record, err := svc.RecordChildDataConsent(ctx, user.ID, CurrentConsentVersion, true, "2.2.2.2", "d2")
	if err != nil {
		t.Fatalf("second record: %v", err)
	}
	if !record.AgreedAt.Equal(second) {
		t.Fatalf("agreedAt = %v, want %v", record.AgreedAt, second)
	}
}

func TestGetChildDataConsentStatusWithoutConsent(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_status_none", AppleSub: "apple-status-none", Region: "cn",
	})

	svc := NewService(mem)
	status, err := svc.GetChildDataConsentStatus(ctx, user.ID)
	if err != nil {
		t.Fatalf("get status: %v", err)
	}
	if status.CurrentVersion != CurrentConsentVersion {
		t.Fatalf("currentVersion = %q", status.CurrentVersion)
	}
	if status.Agreed || !status.RequiresConsent {
		t.Fatalf("expected requires consent: %+v", status)
	}
	if status.AgreedVersion != nil {
		t.Fatalf("agreedVersion should be nil: %+v", status)
	}
}

func TestGetChildDataConsentStatusStaleVersion(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_status_stale", AppleSub: "apple-status-stale", Region: "cn",
	})

	stale := "child_consent_v0"
	fixed := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	if _, err := mem.RecordChildConsent(ctx, store.RecordChildConsentInput{
		UserID: user.ID, Version: stale, AgreedAt: fixed,
	}); err != nil {
		t.Fatalf("seed stale consent: %v", err)
	}

	svc := NewService(mem)
	status, err := svc.GetChildDataConsentStatus(ctx, user.ID)
	if err != nil {
		t.Fatalf("get status: %v", err)
	}
	if status.Agreed {
		t.Fatal("stale version should not count as agreed")
	}
	if !status.RequiresConsent {
		t.Fatal("stale version should require re-consent")
	}
	if status.AgreedVersion == nil || *status.AgreedVersion != stale {
		t.Fatalf("agreedVersion = %v, want %q", status.AgreedVersion, stale)
	}
}

func TestGetChildDataConsentStatusCurrentVersion(t *testing.T) {
	mem := store.NewMemoryStore()
	ctx := context.Background()
	user, _ := mem.CreateUser(ctx, store.CreateUserInput{
		ID: "usr_status_current", AppleSub: "apple-status-current", Region: "cn",
	})

	svc := NewService(mem)
	if _, err := svc.RecordChildDataConsent(ctx, user.ID, CurrentConsentVersion, true, "", ""); err != nil {
		t.Fatalf("record consent: %v", err)
	}

	status, err := svc.GetChildDataConsentStatus(ctx, user.ID)
	if err != nil {
		t.Fatalf("get status: %v", err)
	}
	if !status.Agreed || status.RequiresConsent {
		t.Fatalf("expected valid consent: %+v", status)
	}
	if status.AgreedVersion == nil || *status.AgreedVersion != CurrentConsentVersion {
		t.Fatalf("agreedVersion = %v", status.AgreedVersion)
	}
}
