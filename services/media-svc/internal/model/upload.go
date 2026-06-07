package model

import "time"

// Purpose identifies why an upload session was created.
type Purpose string

const (
	PurposeAIInput  Purpose = "ai-input"
	PurposePostItem Purpose = "post-item"
)

// UploadStatus tracks session lifecycle.
type UploadStatus string

const (
	UploadStatusPending   UploadStatus = "pending"
	UploadStatusCompleted UploadStatus = "completed"
)

// UploadItem describes one file in an upload session.
type UploadItem struct {
	ClientRef string `json:"clientRef"`
	Kind      string `json:"kind,omitempty"`
	Mime      string `json:"mime,omitempty"`
	Size      int64  `json:"size,omitempty"`
	SHA256    string `json:"sha256,omitempty"`
	ObjectKey string `json:"objectKey"`
}

// UploadSession is persisted metadata for a direct upload flow.
type UploadSession struct {
	ID        string
	UserID    string
	Purpose   Purpose
	FamilyID  string
	Region    string
	Status    UploadStatus
	ExpiresAt time.Time
	CreatedAt time.Time
	Items     []UploadItem
}
