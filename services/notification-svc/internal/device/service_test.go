package device

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/notification-svc/internal/store"
)

func validToken() string {
	return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
}

func TestRegisterAndUnregister(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()

	dt, err := svc.Register(ctx, "usr_1", RegisterInput{
		DeviceID:  "dev_1",
		APNSToken: validToken(),
		Region:    "cn",
	})
	if err != nil {
		t.Fatal(err)
	}
	if dt.DeviceID != "dev_1" {
		t.Fatalf("device id = %s", dt.DeviceID)
	}

	if err := svc.Unregister(ctx, "usr_1", "dev_1"); err != nil {
		t.Fatal(err)
	}
	if err := svc.Unregister(ctx, "usr_1", "dev_1"); err != ErrDeviceNotFound {
		t.Fatalf("second unregister err = %v", err)
	}
}

func TestCleanupInvalidToken(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()
	token := validToken()

	_, err := svc.Register(ctx, "usr_1", RegisterInput{
		DeviceID:  "dev_1",
		APNSToken: token,
		Region:    "cn",
	})
	if err != nil {
		t.Fatal(err)
	}

	removed, err := svc.CleanupInvalidToken(ctx, token)
	if err != nil {
		t.Fatal(err)
	}
	if removed != 1 {
		t.Fatalf("removed = %d", removed)
	}
}

func TestRegisterValidation(t *testing.T) {
	svc := NewService(store.NewMemoryStore())
	_, err := svc.Register(context.Background(), "", RegisterInput{DeviceID: "d", APNSToken: validToken(), Region: "cn"})
	if err != ErrUnauthorized {
		t.Fatalf("err = %v", err)
	}
	_, err = svc.Register(context.Background(), "usr_1", RegisterInput{DeviceID: "", APNSToken: validToken(), Region: "cn"})
	if err != ErrBadRequest {
		t.Fatalf("err = %v", err)
	}
	_, err = svc.Register(context.Background(), "usr_1", RegisterInput{DeviceID: "d", APNSToken: "short", Region: "cn"})
	if err != ErrInvalidToken {
		t.Fatalf("err = %v", err)
	}
}

func TestRegisterUpsert(t *testing.T) {
	st := store.NewMemoryStore()
	svc := NewService(st)
	ctx := context.Background()

	in := RegisterInput{DeviceID: "dev_1", APNSToken: validToken(), Region: "os", AppVersion: "1.0.0"}
	dt1, err := svc.Register(ctx, "usr_1", in)
	if err != nil {
		t.Fatal(err)
	}

	in.APNSToken = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
	dt2, err := svc.Register(ctx, "usr_1", in)
	if err != nil {
		t.Fatal(err)
	}
	if dt2.APNSToken == dt1.APNSToken {
		t.Fatal("expected token update")
	}
	if dt2.UpdatedAt.Before(dt1.UpdatedAt.Add(-time.Second)) {
		t.Fatal("expected updated_at refresh")
	}
}
