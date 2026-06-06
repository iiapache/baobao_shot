package store

import (
	"context"
	"testing"
	"time"
)

func TestMemoryRevocationStore(t *testing.T) {
	store := NewMemoryRevocationStore()
	ctx := context.Background()

	revoked, err := store.IsRevoked(ctx, "jti_1")
	if err != nil || revoked {
		t.Fatalf("fresh jti should not be revoked: revoked=%v err=%v", revoked, err)
	}

	if err := store.Revoke(ctx, "jti_1", time.Minute); err != nil {
		t.Fatal(err)
	}
	revoked, err = store.IsRevoked(ctx, "jti_1")
	if err != nil || !revoked {
		t.Fatalf("jti should be revoked: revoked=%v err=%v", revoked, err)
	}

	if err := store.Revoke(ctx, "jti_2", time.Millisecond); err != nil {
		t.Fatal(err)
	}
	time.Sleep(2 * time.Millisecond)
	revoked, err = store.IsRevoked(ctx, "jti_2")
	if err != nil || revoked {
		t.Fatalf("expired blacklist entry should be cleaned: revoked=%v err=%v", revoked, err)
	}
}

func TestNewRevocationStoreDefaultsToMemory(t *testing.T) {
	store := NewRevocationStore("")
	if _, ok := store.(*MemoryRevocationStore); !ok {
		t.Fatalf("expected MemoryRevocationStore, got %T", store)
	}
}

func TestNewRevocationStoreInvalidRedisFallback(t *testing.T) {
	store := NewRevocationStore("redis://127.0.0.1:1")
	if _, ok := store.(*MemoryRevocationStore); !ok {
		t.Fatalf("expected memory fallback, got %T", store)
	}
}
