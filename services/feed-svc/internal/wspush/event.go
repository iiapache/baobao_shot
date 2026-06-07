package wspush

import (
	"context"
	"time"
)

const (
	KindLikeAdded      = "like_added"
	KindLikeRemoved    = "like_removed"
	KindCommentAdded   = "comment_added"
	KindCommentRemoved = "comment_removed"
)

// Event is a feed engagement delta pushed to subscribed clients.
type Event struct {
	Kind      string
	FamilyID  string
	PostID    string
	UserID    string
	CommentID string
	Text      string
	LikedAt   *time.Time
	CreatedAt *time.Time
}

// Pusher publishes feed engagement events to realtime subscribers.
type Pusher interface {
	PublishFeedEvent(ctx context.Context, event Event) error
}
