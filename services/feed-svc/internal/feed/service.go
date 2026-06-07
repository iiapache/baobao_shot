package feed

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/feed-svc/internal/cache"
	"github.com/baobao/feed-svc/internal/familyauth"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
)

const feedCacheTTL = 60 * time.Second

// ListInput is the service-layer family feed request.
type ListInput struct {
	UserID   string
	FamilyID string
	Cursor   string
	Limit    int
}

// ItemMedia is one media attachment in a feed item.
type ItemMedia struct {
	ItemID       string  `json:"itemId"`
	Kind         string  `json:"kind"`
	ObjectKey    string  `json:"objectKey"`
	Mime         string  `json:"mime,omitempty"`
	Width        int     `json:"width"`
	Height       int     `json:"height"`
	Duration     *int    `json:"duration,omitempty"`
	DeepSynth    bool    `json:"deepSynth"`
	ThumbnailKey *string `json:"thumbnailKey,omitempty"`
}

// FeedItem is one post in the family feed list.
type FeedItem struct {
	PostID      string      `json:"postId"`
	FamilyID    string      `json:"familyId"`
	OwnerUserID string      `json:"ownerUserId"`
	BabyIDs     []string    `json:"babyIds"`
	Caption     string      `json:"caption"`
	Visibility  string      `json:"visibility"`
	Status      string      `json:"status"`
	CreatedAt   string      `json:"createdAt"`
	Items       []ItemMedia `json:"items"`
}

// ListOutput is GET /v1/feeds/family payload.
type ListOutput struct {
	Items           []FeedItem `json:"items"`
	NextCursor      *string    `json:"nextCursor,omitempty"`
	CacheTTLSeconds int        `json:"cacheTtlSeconds"`
}

type cachedPage struct {
	Items      []FeedItem `json:"items"`
	NextCursor string     `json:"nextCursor,omitempty"`
}

// Service serves family feed list queries with Redis/memory cache.
type Service struct {
	store  store.Store
	cache  cache.Store
	family familyauth.Client
	ttl    time.Duration
}

// NewService wires feed list business logic.
func NewService(st store.Store, c cache.Store, family familyauth.Client) *Service {
	if c == nil {
		c = cache.NewMemoryStore()
	}
	if family == nil {
		family = familyauth.NewStub()
	}
	return &Service{
		store:  st,
		cache:  c,
		family: family,
		ttl:    feedCacheTTL,
	}
}

// List returns a paginated family feed page, using cache when available.
func (s *Service) List(ctx context.Context, in ListInput) (ListOutput, error) {
	in.UserID = strings.TrimSpace(in.UserID)
	in.FamilyID = strings.TrimSpace(in.FamilyID)
	if in.UserID == "" {
		return ListOutput{}, ErrUnauthorized
	}
	if in.FamilyID == "" {
		return ListOutput{}, ErrBadRequest
	}
	if err := s.family.CanAccessFamilyFeed(ctx, in.FamilyID); err != nil {
		if errors.Is(err, familyauth.ErrForbidden) {
			return ListOutput{}, ErrFamilyForbidden
		}
		return ListOutput{}, err
	}

	cacheKey := feedCacheKey(in.FamilyID, in.Cursor, in.Limit)
	if raw, ok, err := s.cache.Get(ctx, cacheKey); err != nil {
		return ListOutput{}, fmt.Errorf("feed cache get: %w", err)
	} else if ok {
		var page cachedPage
		if err := json.Unmarshal(raw, &page); err != nil {
			return ListOutput{}, fmt.Errorf("feed cache decode: %w", err)
		}
		return toListOutput(page), nil
	}

	page, err := s.store.ListFamilyPosts(ctx, store.ListFamilyPostsInput{
		FamilyID: in.FamilyID,
		Cursor:   in.Cursor,
		Limit:    in.Limit,
	})
	if err != nil {
		return ListOutput{}, err
	}

	cached := cachedPage{Items: make([]FeedItem, 0, len(page.Posts))}
	for _, post := range page.Posts {
		item, err := s.toFeedItem(ctx, post)
		if err != nil {
			return ListOutput{}, err
		}
		cached.Items = append(cached.Items, item)
	}
	cached.NextCursor = page.NextCursor

	raw, err := json.Marshal(cached)
	if err != nil {
		return ListOutput{}, err
	}
	if err := s.cache.Set(ctx, cacheKey, raw, s.ttl); err != nil {
		return ListOutput{}, fmt.Errorf("feed cache set: %w", err)
	}

	return toListOutput(cached), nil
}

func (s *Service) toFeedItem(ctx context.Context, post model.Post) (FeedItem, error) {
	items, err := s.store.ListPostItems(ctx, post.ID)
	if err != nil {
		return FeedItem{}, err
	}
	media := make([]ItemMedia, 0, len(items))
	for _, item := range items {
		media = append(media, ItemMedia{
			ItemID:       item.ID,
			Kind:         item.Kind,
			ObjectKey:    item.ObjectKey,
			Mime:         item.Mime,
			Width:        item.Width,
			Height:       item.Height,
			Duration:     item.Duration,
			DeepSynth:    item.DeepSynth,
			ThumbnailKey: item.ThumbnailKey,
		})
	}
	return FeedItem{
		PostID:      post.ID,
		FamilyID:    post.FamilyID,
		OwnerUserID: post.OwnerUserID,
		BabyIDs:     append([]string(nil), post.BabyIDs...),
		Caption:     post.Caption,
		Visibility:  post.Visibility,
		Status:      post.Status,
		CreatedAt:   post.CreatedAt.UTC().Format(time.RFC3339),
		Items:       media,
	}, nil
}

func toListOutput(page cachedPage) ListOutput {
	out := ListOutput{
		Items:           page.Items,
		CacheTTLSeconds: int(feedCacheTTL.Seconds()),
	}
	if page.NextCursor != "" {
		cursor := page.NextCursor
		out.NextCursor = &cursor
	}
	return out
}

func feedCacheKey(familyID, cursor string, limit int) string {
	cursorKey := strings.TrimSpace(cursor)
	if cursorKey == "" {
		cursorKey = "_"
	}
	return familyID + ":" + cursorKey + ":" + fmt.Sprintf("%d", store.NormalizeFeedLimit(limit))
}
