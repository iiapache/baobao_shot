package avatar

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Storage persists baby avatar objects (local stub or future OSS adapter).
type Storage interface {
	Save(ctx context.Context, babyID string, data []byte, contentType string) (url string, err error)
}

// LocalStorage writes avatars under baseDir/avatar/{babyID}.jpg.
type LocalStorage struct {
	BaseDir string
	CDNBase string
}

// NewLocalStorage returns a local avatar storage stub.
func NewLocalStorage(baseDir, cdnBase string) *LocalStorage {
	if baseDir == "" {
		baseDir = "./data/avatar"
	}
	return &LocalStorage{BaseDir: baseDir, CDNBase: strings.TrimRight(cdnBase, "/")}
}

// Save writes avatar bytes and returns a CDN-style object key URL.
func (s *LocalStorage) Save(_ context.Context, babyID string, data []byte, contentType string) (string, error) {
	if babyID == "" {
		return "", fmt.Errorf("baby id required")
	}
	ext := extensionForContentType(contentType)
	dir := filepath.Join(s.BaseDir, "avatar")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("mkdir avatar: %w", err)
	}
	objectKey := fmt.Sprintf("avatar/%s%s", babyID, ext)
	path := filepath.Join(s.BaseDir, objectKey)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return "", fmt.Errorf("write avatar: %w", err)
	}
	if s.CDNBase != "" {
		return s.CDNBase + "/" + objectKey, nil
	}
	return objectKey, nil
}

func extensionForContentType(contentType string) string {
	switch strings.ToLower(strings.TrimSpace(contentType)) {
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	default:
		return ".jpg"
	}
}
