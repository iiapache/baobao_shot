package cache

import (
	"context"
	"testing"
	"time"
)

func TestMemoryStoreSetGetTTL(t *testing.T) {
	st := NewMemoryStore()
	ctx := context.Background()

	if err := st.Set(ctx, "fam_1:_:20", []byte(`{"items":[]}`), time.Second); err != nil {
		t.Fatal(err)
	}
	val, ok, err := st.Get(ctx, "fam_1:_:20")
	if err != nil || !ok || string(val) != `{"items":[]}` {
		t.Fatalf("get = %q ok=%v err=%v", val, ok, err)
	}

	time.Sleep(1100 * time.Millisecond)
	_, ok, err = st.Get(ctx, "fam_1:_:20")
	if err != nil || ok {
		t.Fatalf("expected expired cache entry, ok=%v err=%v", ok, err)
	}
}

func TestMemoryStoreMiss(t *testing.T) {
	st := NewMemoryStore()
	_, ok, err := st.Get(context.Background(), "missing")
	if err != nil || ok {
		t.Fatalf("ok=%v err=%v", ok, err)
	}
}

func TestNewUsesMemoryWithoutRedisURL(t *testing.T) {
	st := New("")
	if _, ok := st.(*MemoryStore); !ok {
		t.Fatalf("store type = %T", st)
	}
}
