package store

import (
	"context"
	"sort"

	"github.com/baobao/feed-svc/internal/model"
)

func (s *MemoryStore) ListFamilyPosts(_ context.Context, in ListFamilyPostsInput) (ListFamilyPostsResult, error) {
	limit := NormalizeFeedLimit(in.Limit)
	cursorTime, cursorID, err := ParseFeedCursor(in.Cursor)
	if err != nil {
		return ListFamilyPostsResult{}, err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	var posts []*model.Post
	for _, post := range s.posts {
		if post.FamilyID != in.FamilyID || !isFamilyFeedPost(post) {
			continue
		}
		posts = append(posts, clonePost(post))
	}

	sort.Slice(posts, func(i, j int) bool {
		if posts[i].CreatedAt.Equal(posts[j].CreatedAt) {
			return posts[i].ID > posts[j].ID
		}
		return posts[i].CreatedAt.After(posts[j].CreatedAt)
	})

	if !cursorTime.IsZero() {
		filtered := posts[:0]
		for _, post := range posts {
			if post.CreatedAt.Before(cursorTime) {
				filtered = append(filtered, post)
				continue
			}
			if post.CreatedAt.Equal(cursorTime) && post.ID < cursorID {
				filtered = append(filtered, post)
			}
		}
		posts = filtered
	}

	result := ListFamilyPostsResult{}
	if len(posts) > limit {
		page := posts[:limit]
		result.Posts = clonePosts(page)
		result.NextCursor = EncodeFeedCursor(*posts[limit-1])
		return result, nil
	}

	result.Posts = clonePosts(posts)
	return result, nil
}

func clonePosts(posts []*model.Post) []model.Post {
	out := make([]model.Post, 0, len(posts))
	for _, post := range posts {
		if post == nil {
			continue
		}
		out = append(out, *post)
	}
	return out
}
