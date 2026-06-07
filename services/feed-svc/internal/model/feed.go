package model

import "time"

const (
	VisibilityFamily = "family"
	VisibilitySelf   = "self"

	PostStatusAudit     = "audit"
	PostStatusPublished = "published"
	PostStatusRemoved   = "removed"

	ItemKindImage = "image"
	ItemKindVideo = "video"

	CommentStatusPublished = "published"
	CommentStatusRemoved   = "removed"
)

// Post is a feed post scoped to a family.
type Post struct {
	ID          string
	FamilyID    string
	OwnerUserID string
	BabyIDs     []string
	Caption     string
	Visibility  string
	Status      string
	CreatedAt   time.Time
	AuditedAt   *time.Time
	DeletedAt   *time.Time
}

// PostItem is a media attachment belonging to a post.
type PostItem struct {
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
	DeletedAt    *time.Time
}

// Comment is a user comment on a post.
type Comment struct {
	ID        string
	PostID    string
	UserID    string
	ParentID  *string
	Text      string
	Status    string
	CreatedAt time.Time
	DeletedAt *time.Time
}

// Like records a user's like on a post.
type Like struct {
	PostID  string
	UserID  string
	LikedAt time.Time
}

// FeedAuditLog records moderation outcomes for feed UGC.
type FeedAuditLog struct {
	ID         string
	TargetKind string
	TargetID   string
	Result     string
	Reasons    []string
	Reviewer   string
	CreatedAt  time.Time
}
