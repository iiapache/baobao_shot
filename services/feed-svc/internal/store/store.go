package store

import "context"

// Store is the persistence boundary for feed-svc.
type Store interface {
	PostStore
	FeedStore
	CommentStore
	LikeStore
	AuditLogStore
	Ping(ctx context.Context) error
}
