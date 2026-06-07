package watermark

import (
	"context"
	"fmt"
	"sync"
)

// ArtifactStore loads and persists generated artifacts for watermarking.
type ArtifactStore interface {
	Get(ctx context.Context, objectKey string) ([]byte, error)
	Put(ctx context.Context, objectKey string, data []byte, contentType string) error
}

// MemoryArtifactStore is an in-memory blob store for tests and local dev.
type MemoryArtifactStore struct {
	mu    sync.RWMutex
	blobs map[string][]byte
}

// NewMemoryArtifactStore creates an empty artifact store.
func NewMemoryArtifactStore() *MemoryArtifactStore {
	return &MemoryArtifactStore{blobs: make(map[string][]byte)}
}

// Get returns artifact bytes by object key.
func (s *MemoryArtifactStore) Get(_ context.Context, objectKey string) ([]byte, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	data, ok := s.blobs[objectKey]
	if !ok {
		return nil, fmt.Errorf("artifact %q not found", objectKey)
	}
	out := make([]byte, len(data))
	copy(out, data)
	return out, nil
}

// Put stores artifact bytes.
func (s *MemoryArtifactStore) Put(_ context.Context, objectKey string, data []byte, _ string) error {
	if objectKey == "" {
		return fmt.Errorf("object key required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	copyData := make([]byte, len(data))
	copy(copyData, data)
	s.blobs[objectKey] = copyData
	return nil
}
