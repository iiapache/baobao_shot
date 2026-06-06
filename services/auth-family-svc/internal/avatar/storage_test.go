package avatar_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/baobao/auth-family-svc/internal/avatar"
)

func TestLocalStorageSave(t *testing.T) {
	dir := t.TempDir()
	storage := avatar.NewLocalStorage(dir, "https://cdn.example.com")

	url, err := storage.Save(context.Background(), "bb_test001", []byte("fake-image"), "image/jpeg")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://cdn.example.com/avatar/bb_test001.jpg" {
		t.Fatalf("url = %q", url)
	}

	path := filepath.Join(dir, "avatar", "bb_test001.jpg")
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("file missing: %v", err)
	}
}
