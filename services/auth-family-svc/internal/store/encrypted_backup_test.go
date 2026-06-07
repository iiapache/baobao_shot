package store

import (
	"context"
	"testing"
	"time"

	"github.com/baobao/auth-family-svc/internal/crypto/seal"
	"github.com/baobao/auth-family-svc/internal/model"
)

func TestEncryptingBackupStoreSealsTokensAtRest(t *testing.T) {
	mem := NewMemoryStore()
	sealer, err := seal.New(seal.DeriveKeyFromSecret("enc-test-key"))
	if err != nil {
		t.Fatalf("new sealer: %v", err)
	}
	enc := NewEncryptingBackupStore(mem, sealer)
	ctx := context.Background()
	now := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	refresh := "refresh-plain"

	_, err = enc.UpsertBackupProvider(ctx, UpsertBackupProviderInput{
		ID:           "bkp_enc_test",
		UserID:       "usr_enc",
		Kind:         model.BackupProviderKindBaiduPan,
		AccessToken:  "access-plain",
		RefreshToken: &refresh,
		Status:       model.BackupProviderStatusActive,
		Now:          now,
	})
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}

	raw, err := mem.ListBackupProviders(ctx, "usr_enc")
	if err != nil {
		t.Fatalf("raw list: %v", err)
	}
	if len(raw) != 1 {
		t.Fatalf("raw items = %d, want 1", len(raw))
	}
	if raw[0].AccessToken == "access-plain" {
		t.Fatal("access token stored in plaintext")
	}
	if !seal.IsSealed(raw[0].AccessToken) {
		t.Fatalf("access token not sealed: %q", raw[0].AccessToken)
	}
	if raw[0].RefreshToken == nil || *raw[0].RefreshToken == refresh {
		t.Fatal("refresh token stored in plaintext")
	}

	items, err := enc.ListBackupProviders(ctx, "usr_enc")
	if err != nil {
		t.Fatalf("decrypted list: %v", err)
	}
	if items[0].AccessToken != "access-plain" {
		t.Fatalf("decrypted access = %q", items[0].AccessToken)
	}
	if items[0].RefreshToken == nil || *items[0].RefreshToken != refresh {
		t.Fatalf("decrypted refresh = %+v", items[0].RefreshToken)
	}
}
