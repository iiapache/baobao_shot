package store

import (
	"context"
	"sync"

	"github.com/baobao/media-svc/internal/model"
)

// MemoryUploadStore is an in-memory UploadStore for dev and tests.
type MemoryUploadStore struct {
	mu       sync.RWMutex
	sessions map[string]*model.UploadSession
}

// NewMemoryUploadStore creates an empty memory store.
func NewMemoryUploadStore() *MemoryUploadStore {
	return &MemoryUploadStore{sessions: make(map[string]*model.UploadSession)}
}

// CreateSession stores a new upload session.
func (s *MemoryUploadStore) CreateSession(_ context.Context, session *model.UploadSession) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	copySession := cloneSession(session)
	s.sessions[session.ID] = copySession
	return nil
}

// GetSession returns one upload session by id.
func (s *MemoryUploadStore) GetSession(_ context.Context, uploadID string) (*model.UploadSession, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.sessions[uploadID]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneSession(session), nil
}

// UpdateSession replaces an existing upload session.
func (s *MemoryUploadStore) UpdateSession(_ context.Context, session *model.UploadSession) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.sessions[session.ID]; !ok {
		return ErrNotFound
	}
	s.sessions[session.ID] = cloneSession(session)
	return nil
}

func cloneSession(session *model.UploadSession) *model.UploadSession {
	if session == nil {
		return nil
	}
	copyItems := make([]model.UploadItem, len(session.Items))
	copy(copyItems, session.Items)
	copySession := *session
	copySession.Items = copyItems
	return &copySession
}
