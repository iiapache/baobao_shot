package store

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/feed-svc/internal/model"
)

const (
	defaultFeedPageSize = 20
	maxFeedPageSize     = 50
)

// ErrInvalidCursor is returned when a pagination cursor cannot be decoded.
var ErrInvalidCursor = fmt.Errorf("invalid pagination cursor")

// ListFamilyPostsInput filters family-visible feed posts.
type ListFamilyPostsInput struct {
	FamilyID string
	Cursor   string
	Limit    int
}

// ListFamilyPostsResult is a paginated family feed page from the store.
type ListFamilyPostsResult struct {
	Posts      []model.Post
	NextCursor string
}

// FeedStore lists family feed posts.
type FeedStore interface {
	ListFamilyPosts(ctx context.Context, in ListFamilyPostsInput) (ListFamilyPostsResult, error)
}

// ParseFeedCursor decodes a feed pagination cursor.
func ParseFeedCursor(cursor string) (createdAt time.Time, postID string, err error) {
	cursor = strings.TrimSpace(cursor)
	if cursor == "" {
		return time.Time{}, "", nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 || parts[1] == "" {
		return time.Time{}, "", ErrInvalidCursor
	}
	createdAt, err = time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	return createdAt.UTC(), parts[1], nil
}

// EncodeFeedCursor builds an opaque cursor from a post.
func EncodeFeedCursor(post model.Post) string {
	payload := post.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + post.ID
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

// NormalizeFeedLimit clamps page size to API bounds.
func NormalizeFeedLimit(limit int) int {
	if limit <= 0 {
		return defaultFeedPageSize
	}
	if limit > maxFeedPageSize {
		return maxFeedPageSize
	}
	return limit
}

func familyFeedStatuses() map[string]struct{} {
	return map[string]struct{}{
		model.PostStatusPublished: {},
		model.PostStatusAudit:     {},
	}
}

func isFamilyFeedPost(post *model.Post) bool {
	if post == nil || post.DeletedAt != nil {
		return false
	}
	if post.Visibility != model.VisibilityFamily {
		return false
	}
	_, ok := familyFeedStatuses()[post.Status]
	return ok
}
