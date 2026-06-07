package store

import (
	"context"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *MemoryStore) GetSignIn(_ context.Context, userID string, date time.Time) (*model.SignInRecord, error) {
	key := signInKey(userID, date)
	s.mu.RLock()
	defer s.mu.RUnlock()
	rec, ok := s.signIns[key]
	if !ok {
		return nil, ErrNotFound
	}
	copy := rec
	return &copy, nil
}

func (s *MemoryStore) RecordSignIn(_ context.Context, rec model.SignInRecord) (bool, error) {
	key := signInKey(rec.UserID, rec.Date)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.signIns[key]; ok {
		return false, nil
	}
	rec.Date = utcDate(rec.Date)
	s.signIns[key] = rec
	return true, nil
}
