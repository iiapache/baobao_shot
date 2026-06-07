package store

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/baobao/feed-svc/internal/model"
)

// MemoryStore is an in-memory Store for dev and unit tests.
type MemoryStore struct {
	mu         sync.RWMutex
	posts      map[string]*model.Post
	postItems  map[string]*model.PostItem
	itemsByPost map[string][]string
	comments   map[string]*model.Comment
	likes      map[string]model.Like
	auditLogs  map[string]*model.FeedAuditLog
}

// NewMemoryStore returns an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		posts:       make(map[string]*model.Post),
		postItems:   make(map[string]*model.PostItem),
		itemsByPost: make(map[string][]string),
		comments:    make(map[string]*model.Comment),
		likes:       make(map[string]model.Like),
		auditLogs:   make(map[string]*model.FeedAuditLog),
	}
}

func (s *MemoryStore) Ping(_ context.Context) error { return nil }

func (s *MemoryStore) CreatePost(ctx context.Context, in CreatePostInput) (*model.Post, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	babyIDs := append([]string(nil), in.BabyIDs...)
	post := &model.Post{
		ID:          in.ID,
		FamilyID:    in.FamilyID,
		OwnerUserID: in.OwnerUserID,
		BabyIDs:     babyIDs,
		Caption:     in.Caption,
		Visibility:  in.Visibility,
		Status:      in.Status,
		CreatedAt:   in.CreatedAt,
	}
	s.posts[in.ID] = post
	return clonePost(post), nil
}

func (s *MemoryStore) UpdatePostStatus(_ context.Context, postID, status string, auditedAt *time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	post, ok := s.posts[postID]
	if !ok || post.DeletedAt != nil {
		return ErrNotFound
	}
	post.Status = status
	if auditedAt != nil {
		t := *auditedAt
		post.AuditedAt = &t
	}
	return nil
}

func (s *MemoryStore) GetPost(_ context.Context, postID string) (*model.Post, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	post, ok := s.posts[postID]
	if !ok || post.DeletedAt != nil {
		return nil, ErrNotFound
	}
	return clonePost(post), nil
}

func (s *MemoryStore) SoftDeletePost(_ context.Context, postID string, deletedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	post, ok := s.posts[postID]
	if !ok || post.DeletedAt != nil {
		return ErrNotFound
	}
	t := deletedAt
	post.DeletedAt = &t
	post.Status = model.PostStatusRemoved
	return nil
}

func (s *MemoryStore) SoftDeletePostItemsByPostID(_ context.Context, postID string, deletedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.posts[postID]; !ok {
		return ErrNotFound
	}
	t := deletedAt
	for _, itemID := range s.itemsByPost[postID] {
		item := s.postItems[itemID]
		if item == nil || item.DeletedAt != nil {
			continue
		}
		item.DeletedAt = &t
	}
	return nil
}

func (s *MemoryStore) CreatePostItem(_ context.Context, in CreatePostItemInput) (*model.PostItem, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.posts[in.PostID]; !ok {
		return nil, ErrNotFound
	}
	item := &model.PostItem{
		ID:           in.ID,
		PostID:       in.PostID,
		Kind:         in.Kind,
		ObjectKey:    in.ObjectKey,
		Mime:         in.Mime,
		Width:        in.Width,
		Height:       in.Height,
		Duration:     in.Duration,
		DeepSynth:    in.DeepSynth,
		ThumbnailKey: in.ThumbnailKey,
	}
	s.postItems[in.ID] = item
	s.itemsByPost[in.PostID] = append(s.itemsByPost[in.PostID], in.ID)
	return clonePostItem(item), nil
}

func (s *MemoryStore) ListPostItems(_ context.Context, postID string) ([]model.PostItem, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	ids := s.itemsByPost[postID]
	out := make([]model.PostItem, 0, len(ids))
	for _, id := range ids {
		item := s.postItems[id]
		if item == nil || item.DeletedAt != nil {
			continue
		}
		out = append(out, *clonePostItem(item))
	}
	return out, nil
}

func (s *MemoryStore) CreateComment(_ context.Context, in CreateCommentInput) (*model.Comment, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	post, ok := s.posts[in.PostID]
	if !ok || post.DeletedAt != nil {
		return nil, ErrNotFound
	}
	c := &model.Comment{
		ID:        in.ID,
		PostID:    in.PostID,
		UserID:    in.UserID,
		ParentID:  in.ParentID,
		Text:      in.Text,
		Status:    in.Status,
		CreatedAt: in.CreatedAt,
	}
	s.comments[in.ID] = c
	return cloneComment(c), nil
}

func (s *MemoryStore) GetComment(_ context.Context, commentID string) (*model.Comment, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	c, ok := s.comments[commentID]
	if !ok || c.DeletedAt != nil {
		return nil, ErrNotFound
	}
	return cloneComment(c), nil
}

func (s *MemoryStore) SoftDeleteComment(_ context.Context, commentID string, deletedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	c, ok := s.comments[commentID]
	if !ok || c.DeletedAt != nil {
		return ErrNotFound
	}
	t := deletedAt
	c.DeletedAt = &t
	c.Status = model.CommentStatusRemoved
	return nil
}

func (s *MemoryStore) AddLike(_ context.Context, postID, userID string, likedAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.posts[postID]; !ok {
		return ErrNotFound
	}
	key := likeKey(postID, userID)
	if _, exists := s.likes[key]; exists {
		return ErrDuplicateLike
	}
	s.likes[key] = model.Like{PostID: postID, UserID: userID, LikedAt: likedAt}
	return nil
}

func (s *MemoryStore) RemoveLike(_ context.Context, postID, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := likeKey(postID, userID)
	if _, ok := s.likes[key]; !ok {
		return ErrNotFound
	}
	delete(s.likes, key)
	return nil
}

func (s *MemoryStore) CreateAuditLog(_ context.Context, in CreateAuditLogInput) (*model.FeedAuditLog, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	reasons := append([]string(nil), in.Reasons...)
	log := &model.FeedAuditLog{
		ID:         in.ID,
		TargetKind: in.TargetKind,
		TargetID:   in.TargetID,
		Result:     in.Result,
		Reasons:    reasons,
		Reviewer:   in.Reviewer,
		CreatedAt:  in.CreatedAt,
	}
	s.auditLogs[in.ID] = log
	return cloneAuditLog(log), nil
}

func likeKey(postID, userID string) string {
	return postID + "\x00" + userID
}

func clonePost(p *model.Post) *model.Post {
	if p == nil {
		return nil
	}
	cp := *p
	cp.BabyIDs = append([]string(nil), p.BabyIDs...)
	if p.AuditedAt != nil {
		t := *p.AuditedAt
		cp.AuditedAt = &t
	}
	if p.DeletedAt != nil {
		t := *p.DeletedAt
		cp.DeletedAt = &t
	}
	return &cp
}

func clonePostItem(item *model.PostItem) *model.PostItem {
	if item == nil {
		return nil
	}
	cp := *item
	if item.Duration != nil {
		v := *item.Duration
		cp.Duration = &v
	}
	if item.ThumbnailKey != nil {
		v := *item.ThumbnailKey
		cp.ThumbnailKey = &v
	}
	if item.DeletedAt != nil {
		t := *item.DeletedAt
		cp.DeletedAt = &t
	}
	return &cp
}

func cloneComment(c *model.Comment) *model.Comment {
	if c == nil {
		return nil
	}
	cp := *c
	if c.ParentID != nil {
		v := *c.ParentID
		cp.ParentID = &v
	}
	if c.DeletedAt != nil {
		t := *c.DeletedAt
		cp.DeletedAt = &t
	}
	return &cp
}

func cloneAuditLog(l *model.FeedAuditLog) *model.FeedAuditLog {
	if l == nil {
		return nil
	}
	cp := *l
	cp.Reasons = append([]string(nil), l.Reasons...)
	return &cp
}

// encodeJSONStringSlice marshals a string slice for postgres JSONB columns.
func encodeJSONStringSlice(values []string) ([]byte, error) {
	if values == nil {
		values = []string{}
	}
	return json.Marshal(values)
}
