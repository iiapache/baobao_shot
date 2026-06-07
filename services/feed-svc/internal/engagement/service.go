package engagement

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/feed-svc/internal/auditclient"
	"github.com/baobao/feed-svc/internal/familyauth"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/store"
	"github.com/baobao/feed-svc/internal/wspush"
	"github.com/google/uuid"
)

const (
	auditTargetComment = "comment"
	auditReviewer      = "audit-svc"
)

// LikeOutput is POST /v1/posts/{postId}/likes payload.
type LikeOutput struct {
	PostID    string    `json:"postId"`
	UserID    string    `json:"userId"`
	LikedAt   time.Time `json:"likedAt"`
	Duplicate bool      `json:"duplicate,omitempty"`
}

// UnlikeOutput is DELETE /v1/posts/{postId}/likes payload.
type UnlikeOutput struct {
	PostID  string `json:"postId"`
	UserID  string `json:"userId"`
	Removed bool   `json:"removed"`
}

// CreateCommentInput is the service-layer comment request.
type CreateCommentInput struct {
	UserID   string
	Region   string
	PostID   string
	Text     string
	ParentID *string
}

// CommentOutput is POST /v1/posts/{postId}/comments payload.
type CommentOutput struct {
	CommentID string    `json:"commentId"`
	PostID    string    `json:"postId"`
	UserID    string    `json:"userId"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
}

// DeleteCommentOutput is DELETE /v1/posts/{postId}/comments/{commentId} payload.
type DeleteCommentOutput struct {
	CommentID string `json:"commentId"`
	PostID    string `json:"postId"`
	Removed   bool   `json:"removed"`
}

// Service orchestrates likes and comments with UGC audit and WS push.
type Service struct {
	store  store.Store
	audit  auditclient.Client
	family familyauth.Client
	push   wspush.Pusher
	now    func() time.Time
	newID  func() string
}

// NewService wires engagement business logic with sensible defaults.
func NewService(st store.Store, audit auditclient.Client, family familyauth.Client, push wspush.Pusher) *Service {
	if audit == nil {
		audit = auditclient.NewStub()
	}
	if family == nil {
		family = familyauth.NewStub()
	}
	if push == nil {
		push = wspush.NewStub()
	}
	return &Service{
		store:  st,
		audit:  audit,
		family: family,
		push:   push,
		now:    time.Now,
		newID:  newCommentID,
	}
}

func newCommentID() string {
	return "cmt_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
}

// Like adds a like; duplicate likes are idempotent.
func (s *Service) Like(ctx context.Context, userID, postID string) (LikeOutput, error) {
	userID = strings.TrimSpace(userID)
	postID = strings.TrimSpace(postID)
	if userID == "" {
		return LikeOutput{}, ErrUnauthorized
	}
	if postID == "" {
		return LikeOutput{}, ErrBadRequest
	}

	post, err := s.loadEngageablePost(ctx, userID, postID)
	if err != nil {
		return LikeOutput{}, err
	}

	now := s.now().UTC()
	if err := s.store.AddLike(ctx, postID, userID, now); err != nil {
		if errors.Is(err, store.ErrDuplicateLike) {
			return LikeOutput{
				PostID:    postID,
				UserID:    userID,
				LikedAt:   now,
				Duplicate: true,
			}, nil
		}
		return LikeOutput{}, err
	}

	_ = s.push.PublishFeedEvent(ctx, wspush.Event{
		Kind:     wspush.KindLikeAdded,
		FamilyID: post.FamilyID,
		PostID:   postID,
		UserID:   userID,
		LikedAt:  &now,
	})

	return LikeOutput{PostID: postID, UserID: userID, LikedAt: now}, nil
}

// Unlike removes a like; missing likes are idempotent.
func (s *Service) Unlike(ctx context.Context, userID, postID string) (UnlikeOutput, error) {
	userID = strings.TrimSpace(userID)
	postID = strings.TrimSpace(postID)
	if userID == "" {
		return UnlikeOutput{}, ErrUnauthorized
	}
	if postID == "" {
		return UnlikeOutput{}, ErrBadRequest
	}

	post, err := s.loadEngageablePost(ctx, userID, postID)
	if err != nil {
		return UnlikeOutput{}, err
	}

	if err := s.store.RemoveLike(ctx, postID, userID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return UnlikeOutput{PostID: postID, UserID: userID, Removed: true}, nil
		}
		return UnlikeOutput{}, err
	}

	_ = s.push.PublishFeedEvent(ctx, wspush.Event{
		Kind:     wspush.KindLikeRemoved,
		FamilyID: post.FamilyID,
		PostID:   postID,
		UserID:   userID,
	})

	return UnlikeOutput{PostID: postID, UserID: userID, Removed: true}, nil
}

// CreateComment publishes a comment after sync text audit.
func (s *Service) CreateComment(ctx context.Context, in CreateCommentInput) (CommentOutput, error) {
	in.UserID = strings.TrimSpace(in.UserID)
	in.PostID = strings.TrimSpace(in.PostID)
	in.Text = strings.TrimSpace(in.Text)
	if in.UserID == "" {
		return CommentOutput{}, ErrUnauthorized
	}
	if in.PostID == "" || in.Text == "" {
		return CommentOutput{}, ErrBadRequest
	}

	post, err := s.loadEngageablePost(ctx, in.UserID, in.PostID)
	if err != nil {
		return CommentOutput{}, err
	}

	if in.ParentID != nil {
		parentID := strings.TrimSpace(*in.ParentID)
		if parentID == "" {
			return CommentOutput{}, ErrBadRequest
		}
		parent, err := s.store.GetComment(ctx, parentID)
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				return CommentOutput{}, ErrNotFound
			}
			return CommentOutput{}, err
		}
		if parent.PostID != in.PostID {
			return CommentOutput{}, ErrBadRequest
		}
		in.ParentID = &parentID
	}

	region := strings.TrimSpace(in.Region)
	if region == "" {
		region = "cn"
	}

	commentID := s.newID()
	textResult, err := s.audit.AuditTextSync(ctx, auditclient.TextAuditRequest{
		TargetRef: commentID,
		Region:    region,
		Text:      in.Text,
	})
	if err != nil {
		return CommentOutput{}, fmt.Errorf("text audit: %w", err)
	}
	if !textResult.Passed {
		return CommentOutput{}, ErrAuditRejected
	}

	now := s.now().UTC()
	comment, err := s.store.CreateComment(ctx, store.CreateCommentInput{
		ID:        commentID,
		PostID:    in.PostID,
		UserID:    in.UserID,
		ParentID:  in.ParentID,
		Text:      in.Text,
		Status:    model.CommentStatusPublished,
		CreatedAt: now,
	})
	if err != nil {
		return CommentOutput{}, err
	}

	if _, err := s.store.CreateAuditLog(ctx, store.CreateAuditLogInput{
		ID:         "fal_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12],
		TargetKind: auditTargetComment,
		TargetID:   commentID,
		Result:     "passed",
		Reasons:    textResult.Reasons,
		Reviewer:   auditReviewer,
		CreatedAt:  now,
	}); err != nil {
		return CommentOutput{}, err
	}

	_ = s.push.PublishFeedEvent(ctx, wspush.Event{
		Kind:      wspush.KindCommentAdded,
		FamilyID:  post.FamilyID,
		PostID:    in.PostID,
		UserID:    in.UserID,
		CommentID: commentID,
		Text:      in.Text,
		CreatedAt: &now,
	})

	return CommentOutput{
		CommentID: comment.ID,
		PostID:    comment.PostID,
		UserID:    comment.UserID,
		Text:      comment.Text,
		CreatedAt: comment.CreatedAt,
	}, nil
}

// DeleteComment soft-deletes a comment when the caller is the author or post owner.
func (s *Service) DeleteComment(ctx context.Context, userID, postID, commentID string) (DeleteCommentOutput, error) {
	userID = strings.TrimSpace(userID)
	postID = strings.TrimSpace(postID)
	commentID = strings.TrimSpace(commentID)
	if userID == "" {
		return DeleteCommentOutput{}, ErrUnauthorized
	}
	if postID == "" || commentID == "" {
		return DeleteCommentOutput{}, ErrBadRequest
	}

	post, err := s.loadEngageablePost(ctx, userID, postID)
	if err != nil {
		return DeleteCommentOutput{}, err
	}

	comment, err := s.store.GetComment(ctx, commentID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return DeleteCommentOutput{}, ErrNotFound
		}
		return DeleteCommentOutput{}, err
	}
	if comment.PostID != postID {
		return DeleteCommentOutput{}, ErrNotFound
	}
	if comment.UserID != userID && post.OwnerUserID != userID {
		return DeleteCommentOutput{}, ErrForbidden
	}

	now := s.now().UTC()
	if err := s.store.SoftDeleteComment(ctx, commentID, now); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return DeleteCommentOutput{}, ErrNotFound
		}
		return DeleteCommentOutput{}, err
	}

	_ = s.push.PublishFeedEvent(ctx, wspush.Event{
		Kind:      wspush.KindCommentRemoved,
		FamilyID:  post.FamilyID,
		PostID:    postID,
		UserID:    userID,
		CommentID: commentID,
	})

	return DeleteCommentOutput{CommentID: commentID, PostID: postID, Removed: true}, nil
}

func (s *Service) loadEngageablePost(ctx context.Context, userID, postID string) (*model.Post, error) {
	post, err := s.store.GetPost(ctx, postID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if post.Status != model.PostStatusPublished {
		return nil, ErrNotFound
	}
	if err := s.family.CanAccessFamilyFeed(ctx, post.FamilyID); err != nil {
		if errors.Is(err, familyauth.ErrForbidden) {
			return nil, ErrFamilyForbidden
		}
		return nil, err
	}
	return post, nil
}
