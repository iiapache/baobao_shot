package upload

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/model"
	"github.com/baobao/media-svc/internal/store"
	"github.com/google/uuid"
)

// Service orchestrates upload init and complete flows.
type Service struct {
	cfg     *config.Config
	store   store.UploadStore
	sts     STSProvider
	keys    *ObjectKeyBuilder
	now     func() time.Time
	newID   func() string
}

// NewService wires upload business logic.
func NewService(cfg *config.Config, st store.UploadStore, sts STSProvider) *Service {
	if cfg == nil {
		cfg = &config.Config{
			ServiceName:   "media-svc",
			STSTTLSeconds: config.DefaultSTSTTLSeconds,
			OSSBucket:     config.DefaultOSSBucket,
			OSSEndpoint:   config.DefaultOSSEndpoint,
		}
	}
	if sts == nil {
		sts = &MockSTSProvider{}
	}
	return &Service{
		cfg:   cfg,
		store: st,
		sts:   sts,
		keys:  NewObjectKeyBuilder(cfg),
		now:   time.Now,
		newID: newUploadID,
	}
}

func newUploadID() string {
	return "upl_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
}

// Init validates input, persists session metadata, and returns STS + upload targets.
func (s *Service) Init(ctx context.Context, in InitInput) (InitOutput, error) {
	if err := validateInitInput(in); err != nil {
		return InitOutput{}, err
	}

	uploadID := s.newID()
	ttl := time.Duration(s.cfg.STSTTLSeconds) * time.Second
	expiresAt := s.now().UTC().Add(ttl)

	items := make([]model.UploadItem, 0, len(in.Items))
	objectKeys := make([]string, 0, len(in.Items))
	outItems := make([]InitItemOutput, 0, len(in.Items))

	for _, item := range in.Items {
		objectKey := s.keys.Build(in.Purpose, in.UserID, in.FamilyID, uploadID, item.ClientRef, item.Mime)
		objectKeys = append(objectKeys, objectKey)
		items = append(items, model.UploadItem{
			ClientRef: item.ClientRef,
			Kind:      item.Kind,
			Mime:      item.Mime,
			Size:      item.Size,
			SHA256:    item.SHA256,
			ObjectKey: objectKey,
		})
		headers := map[string]string{}
		if item.Mime != "" {
			headers["Content-Type"] = item.Mime
		}
		outItems = append(outItems, InitItemOutput{
			ClientRef: item.ClientRef,
			ObjectKey: objectKey,
			UploadURL: s.keys.UploadURL(objectKey),
			Method:    "PUT",
			Headers:   headers,
			ExpiresIn: s.cfg.STSTTLSeconds,
		})
	}

	sts, err := s.sts.Issue(in.UserID, in.Region, objectKeys, ttl)
	if err != nil {
		return InitOutput{}, fmt.Errorf("issue sts: %w", err)
	}

	session := &model.UploadSession{
		ID:        uploadID,
		UserID:    in.UserID,
		Purpose:   in.Purpose,
		FamilyID:  in.FamilyID,
		Region:    in.Region,
		Status:    model.UploadStatusPending,
		ExpiresAt: expiresAt,
		CreatedAt: s.now().UTC(),
		Items:     items,
	}
	if err := s.store.CreateSession(ctx, session); err != nil {
		return InitOutput{}, err
	}

	return InitOutput{
		UploadID: uploadID,
		STS:      sts,
		Items:    outItems,
	}, nil
}

// Complete marks an upload session as completed after client-side PUT.
func (s *Service) Complete(ctx context.Context, in CompleteInput) (CompleteOutput, error) {
	if in.UserID == "" {
		return CompleteOutput{}, ErrUnauthorized
	}
	if strings.TrimSpace(in.UploadID) == "" {
		return CompleteOutput{}, fmt.Errorf("%w: uploadId required", ErrBadRequest)
	}

	session, err := s.store.GetSession(ctx, in.UploadID)
	if err != nil {
		return CompleteOutput{}, err
	}
	if session.UserID != in.UserID {
		return CompleteOutput{}, ErrForbidden
	}
	if session.Status == model.UploadStatusCompleted {
		return CompleteOutput{}, ErrAlreadyCompleted
	}
	if s.now().UTC().After(session.ExpiresAt) {
		return CompleteOutput{}, ErrSessionExpired
	}

	session.Status = model.UploadStatusCompleted
	if err := s.store.UpdateSession(ctx, session); err != nil {
		return CompleteOutput{}, err
	}

	outItems := make([]CompleteItemOutput, 0, len(session.Items))
	for _, item := range session.Items {
		outItems = append(outItems, CompleteItemOutput{
			ClientRef: item.ClientRef,
			ObjectKey: item.ObjectKey,
			SHA256:    item.SHA256,
			Size:      item.Size,
			Mime:      item.Mime,
		})
	}

	return CompleteOutput{
		UploadID: session.ID,
		Status:   string(model.UploadStatusCompleted),
		Items:    outItems,
	}, nil
}

func validateInitInput(in InitInput) error {
	if in.UserID == "" {
		return ErrUnauthorized
	}
	if in.Region != "cn" && in.Region != "os" {
		return fmt.Errorf("%w: region required (cn|os)", ErrBadRequest)
	}
	switch in.Purpose {
	case model.PurposeAIInput, model.PurposePostItem:
	default:
		return fmt.Errorf("%w: purpose must be ai-input or post-item", ErrBadRequest)
	}
	if in.Purpose == model.PurposePostItem && strings.TrimSpace(in.FamilyID) == "" {
		return fmt.Errorf("%w: familyId required for post-item", ErrBadRequest)
	}
	if len(in.Items) == 0 {
		return fmt.Errorf("%w: items required", ErrBadRequest)
	}
	for _, item := range in.Items {
		if strings.TrimSpace(item.ClientRef) == "" {
			return fmt.Errorf("%w: clientRef required", ErrBadRequest)
		}
	}
	return nil
}
