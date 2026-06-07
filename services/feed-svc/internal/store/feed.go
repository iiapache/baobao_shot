package store

import (
	"context"
	"time"

	"github.com/baobao/feed-svc/internal/model"
)

// CreatePostInput holds fields for inserting a post.
type CreatePostInput struct {
	ID          string
	FamilyID    string
	OwnerUserID string
	BabyIDs     []string
	Caption     string
	Visibility  string
	Status      string
	CreatedAt   time.Time
}

// CreatePostItemInput holds fields for inserting a post item.
type CreatePostItemInput struct {
	ID           string
	PostID       string
	Kind         string
	ObjectKey    string
	Mime         string
	Width        int
	Height       int
	Duration     *int
	DeepSynth    bool
	ThumbnailKey *string
}

// CreateCommentInput holds fields for inserting a comment.
type CreateCommentInput struct {
	ID        string
	PostID    string
	UserID    string
	ParentID  *string
	Text      string
	Status    string
	CreatedAt time.Time
}

// CreateAuditLogInput holds fields for inserting a feed audit log.
type CreateAuditLogInput struct {
	ID         string
	TargetKind string
	TargetID   string
	Result     string
	Reasons    []string
	Reviewer   string
	CreatedAt  time.Time
}

// PostStore persists posts and post items.
type PostStore interface {
	CreatePost(ctx context.Context, in CreatePostInput) (*model.Post, error)
	GetPost(ctx context.Context, postID string) (*model.Post, error)
	UpdatePostStatus(ctx context.Context, postID, status string, auditedAt *time.Time) error
	SoftDeletePost(ctx context.Context, postID string, deletedAt time.Time) error
	SoftDeletePostItemsByPostID(ctx context.Context, postID string, deletedAt time.Time) error
	CreatePostItem(ctx context.Context, in CreatePostItemInput) (*model.PostItem, error)
	ListPostItems(ctx context.Context, postID string) ([]model.PostItem, error)
}

// CommentStore persists comments.
type CommentStore interface {
	CreateComment(ctx context.Context, in CreateCommentInput) (*model.Comment, error)
	GetComment(ctx context.Context, commentID string) (*model.Comment, error)
	SoftDeleteComment(ctx context.Context, commentID string, deletedAt time.Time) error
}

// LikeStore persists likes.
type LikeStore interface {
	AddLike(ctx context.Context, postID, userID string, likedAt time.Time) error
	RemoveLike(ctx context.Context, postID, userID string) error
}

// AuditLogStore persists feed moderation audit logs.
type AuditLogStore interface {
	CreateAuditLog(ctx context.Context, in CreateAuditLogInput) (*model.FeedAuditLog, error)
}
