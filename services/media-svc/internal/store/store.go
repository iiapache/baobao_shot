package store

import (
	"context"
	"errors"

	"github.com/baobao/media-svc/internal/model"
)

var ErrNotFound = errors.New("not found")

// UploadStore persists upload session metadata.
type UploadStore interface {
	CreateSession(ctx context.Context, session *model.UploadSession) error
	GetSession(ctx context.Context, uploadID string) (*model.UploadSession, error)
	UpdateSession(ctx context.Context, session *model.UploadSession) error
}
