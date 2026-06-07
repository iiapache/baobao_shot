package post

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/feed-svc/internal/auditclient"
	"github.com/baobao/feed-svc/internal/mediaclient"
	"github.com/baobao/feed-svc/internal/model"
	"github.com/baobao/feed-svc/internal/ratelimit"
	"github.com/baobao/feed-svc/internal/store"
	"github.com/google/uuid"
)

const (
	maxImages        = 9
	maxVideos        = 1
	postRateWindow   = 60 * time.Second
	postRateMax      = 5
	auditTargetPost  = "post"
	auditTargetMedia = "post_item"
	auditReviewer    = "audit-svc"
)

// CreateItemInput is one media attachment on a post.
type CreateItemInput struct {
	Kind         string
	ObjectKey    string
	Mime         string
	Width        int
	Height       int
	Duration     *int
	DeepSynth    bool
	ThumbnailKey *string
}

// CreateInput is the service-layer publish request.
type CreateInput struct {
	UserID     string
	Region     string
	FamilyID   string
	BabyIDs    []string
	Caption    string
	Visibility string
	Items      []CreateItemInput
}

// CreateOutput is the publish result returned to clients.
type CreateOutput struct {
	PostID    string    `json:"postId"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"createdAt"`
}

// DeleteOutput is the withdraw result returned to clients.
type DeleteOutput struct {
	PostID    string    `json:"postId"`
	Status    string    `json:"status"`
	DeletedAt time.Time `json:"deletedAt"`
}

// Service orchestrates post publish with UGC audit and rate limits.
type Service struct {
	store  store.Store
	audit  auditclient.Client
	media  mediaclient.Client
	limit  *ratelimit.SlidingWindow
	now    func() time.Time
	newID  func() string
}

// NewService wires publish business logic with sensible defaults.
func NewService(st store.Store, audit auditclient.Client, limit *ratelimit.SlidingWindow, media mediaclient.Client) *Service {
	if audit == nil {
		audit = auditclient.NewStub()
	}
	if media == nil {
		media = mediaclient.NewStub()
	}
	if limit == nil {
		limit = ratelimit.NewSlidingWindow()
	}
	return &Service{
		store: st,
		audit: audit,
		media: media,
		limit: limit,
		now:   time.Now,
		newID: newPostID,
	}
}

func newPostID() string {
	return "pst_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
}

// Create publishes a post after sync text audit and optional async media audit enqueue.
func (s *Service) Create(ctx context.Context, in CreateInput) (CreateOutput, error) {
	if strings.TrimSpace(in.UserID) == "" {
		return CreateOutput{}, ErrUnauthorized
	}
	if err := validateCreateInput(in); err != nil {
		return CreateOutput{}, err
	}

	now := s.now().UTC()
	if !s.limit.Allow("post:"+in.UserID, now, ratelimit.Config{Window: postRateWindow, Max: postRateMax}) {
		return CreateOutput{}, ErrRateLimited
	}

	region := strings.TrimSpace(in.Region)
	if region == "" {
		region = "cn"
	}

	postID := s.newID()
	textResult, err := s.audit.AuditTextSync(ctx, auditclient.TextAuditRequest{
		TargetRef: postID,
		Region:    region,
		Text:      in.Caption,
	})
	if err != nil {
		return CreateOutput{}, fmt.Errorf("text audit: %w", err)
	}
	if !textResult.Passed {
		return CreateOutput{}, ErrAuditRejected
	}

	status := model.PostStatusPublished
	if len(in.Items) > 0 {
		status = model.PostStatusAudit
	}

	post, err := s.store.CreatePost(ctx, store.CreatePostInput{
		ID:          postID,
		FamilyID:    in.FamilyID,
		OwnerUserID: in.UserID,
		BabyIDs:     append([]string(nil), in.BabyIDs...),
		Caption:     in.Caption,
		Visibility:  in.Visibility,
		Status:      status,
		CreatedAt:   now,
	})
	if err != nil {
		return CreateOutput{}, err
	}

	if _, err := s.store.CreateAuditLog(ctx, store.CreateAuditLogInput{
		ID:         "fal_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12],
		TargetKind: auditTargetPost,
		TargetID:   postID,
		Result:     "passed",
		Reasons:    textResult.Reasons,
		Reviewer:   auditReviewer,
		CreatedAt:  now,
	}); err != nil {
		return CreateOutput{}, err
	}

	for _, item := range in.Items {
		itemID := "pit_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
		if _, err := s.store.CreatePostItem(ctx, store.CreatePostItemInput{
			ID:           itemID,
			PostID:       postID,
			Kind:         item.Kind,
			ObjectKey:    item.ObjectKey,
			Mime:         item.Mime,
			Width:        item.Width,
			Height:       item.Height,
			Duration:     item.Duration,
			DeepSynth:    item.DeepSynth,
			ThumbnailKey: item.ThumbnailKey,
		}); err != nil {
			return CreateOutput{}, err
		}

		mediaResult, err := s.audit.EnqueueMediaAsync(ctx, auditclient.MediaAuditRequest{
			TargetRef: postID,
			Region:    region,
			MediaType: item.Kind,
			ObjectKey: item.ObjectKey,
		})
		if err != nil {
			return CreateOutput{}, fmt.Errorf("media audit enqueue: %w", err)
		}
		if _, err := s.store.CreateAuditLog(ctx, store.CreateAuditLogInput{
			ID:         "fal_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12],
			TargetKind: auditTargetMedia,
			TargetID:   itemID,
			Result:     "pending",
			Reasons:    []string{mediaResult.JobID},
			Reviewer:   auditReviewer,
			CreatedAt:  now,
		}); err != nil {
			return CreateOutput{}, err
		}
	}

	return CreateOutput{
		PostID:    post.ID,
		Status:    post.Status,
		CreatedAt: post.CreatedAt,
	}, nil
}

// Delete withdraws a published post, soft-deletes metadata, and enqueues OSS cleanup.
func (s *Service) Delete(ctx context.Context, userID, postID, region string) (DeleteOutput, error) {
	userID = strings.TrimSpace(userID)
	postID = strings.TrimSpace(postID)
	if userID == "" {
		return DeleteOutput{}, ErrUnauthorized
	}
	if postID == "" {
		return DeleteOutput{}, ErrBadRequest
	}

	post, err := s.store.GetPost(ctx, postID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return DeleteOutput{}, ErrNotFound
		}
		return DeleteOutput{}, err
	}
	if post.OwnerUserID != userID {
		return DeleteOutput{}, ErrForbidden
	}

	now := s.now().UTC()
	items, err := s.store.ListPostItems(ctx, postID)
	if err != nil {
		return DeleteOutput{}, err
	}

	if err := s.store.SoftDeletePost(ctx, postID, now); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return DeleteOutput{}, ErrNotFound
		}
		return DeleteOutput{}, err
	}
	if err := s.store.SoftDeletePostItemsByPostID(ctx, postID, now); err != nil {
		return DeleteOutput{}, err
	}

	deleteReqs := collectObjectDeleteRequests(postID, region, items)
	if _, err := s.media.EnqueueDeletes(ctx, deleteReqs); err != nil {
		return DeleteOutput{}, fmt.Errorf("oss cleanup enqueue: %w", err)
	}

	return DeleteOutput{
		PostID:    postID,
		Status:    model.PostStatusRemoved,
		DeletedAt: now,
	}, nil
}

func collectObjectDeleteRequests(postID, region string, items []model.PostItem) []mediaclient.DeleteRequest {
	reqs := make([]mediaclient.DeleteRequest, 0, len(items)*2)
	seen := make(map[string]struct{}, len(items)*2)
	add := func(key string) {
		key = strings.TrimSpace(key)
		if key == "" {
			return
		}
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		reqs = append(reqs, mediaclient.DeleteRequest{
			PostID:    postID,
			ObjectKey: key,
			Region:    region,
		})
	}
	for _, item := range items {
		add(item.ObjectKey)
		if item.ThumbnailKey != nil {
			add(*item.ThumbnailKey)
		}
	}
	return reqs
}

// CompleteMediaAudit applies async media audit outcome to the post status.
func (s *Service) CompleteMediaAudit(ctx context.Context, postID string, passed bool) error {
	now := s.now().UTC()
	if passed {
		return s.store.UpdatePostStatus(ctx, postID, model.PostStatusPublished, &now)
	}
	return s.store.SoftDeletePost(ctx, postID, now)
}

func validateCreateInput(in CreateInput) error {
	if strings.TrimSpace(in.FamilyID) == "" {
		return ErrBadRequest
	}
	visibility := strings.TrimSpace(in.Visibility)
	if visibility == "" {
		return ErrBadRequest
	}
	if visibility != model.VisibilityFamily && visibility != model.VisibilitySelf {
		return ErrBadRequest
	}
	return validateItems(in.Items)
}

func validateItems(items []CreateItemInput) error {
	var images, videos int
	for _, item := range items {
		switch item.Kind {
		case model.ItemKindImage:
			images++
		case model.ItemKindVideo:
			videos++
		default:
			return ErrBadRequest
		}
		if strings.TrimSpace(item.ObjectKey) == "" {
			return ErrBadRequest
		}
	}
	if images > maxImages || videos > maxVideos {
		return ErrItemLimit
	}
	return nil
}
