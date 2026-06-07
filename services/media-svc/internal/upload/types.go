package upload

import (
	"strings"
	"time"

	"github.com/baobao/media-svc/internal/config"
	"github.com/baobao/media-svc/internal/model"
)

// STSCredentials are temporary OSS credentials returned to the client.
type STSCredentials struct {
	AccessKeyID     string `json:"accessKeyId"`
	AccessKeySecret string `json:"accessKeySecret"`
	SecurityToken   string `json:"securityToken"`
	Expiration      string `json:"expiration"`
}

// STSProvider issues temporary object-storage credentials.
type STSProvider interface {
	Issue(userID, region string, objectKeys []string, ttl time.Duration) (STSCredentials, error)
}

// MockSTSProvider returns deterministic stub credentials for dev/test.
type MockSTSProvider struct {
	Now func() time.Time
}

// Issue creates mock STS credentials scoped to the requested object keys.
func (p *MockSTSProvider) Issue(userID, region string, objectKeys []string, ttl time.Duration) (STSCredentials, error) {
	now := time.Now
	if p.Now != nil {
		now = p.Now
	}
	exp := now().UTC().Add(ttl)
	return STSCredentials{
		AccessKeyID:     "STS.mock." + sanitizeID(userID),
		AccessKeySecret: "mock-secret-" + region,
		SecurityToken:   "mock-token-" + sanitizeID(userID),
		Expiration:      exp.Format(time.RFC3339),
	}, nil
}

func sanitizeID(id string) string {
	id = strings.ReplaceAll(id, "/", "_")
	if len(id) > 16 {
		return id[:16]
	}
	return id
}

// InitItemInput describes one client-side upload item.
type InitItemInput struct {
	ClientRef string
	Kind      string
	Mime      string
	Size      int64
	SHA256    string
}

// InitInput is the service-layer init request.
type InitInput struct {
	UserID   string
	Region   string
	Purpose  model.Purpose
	FamilyID string
	Items    []InitItemInput
}

// InitItemOutput is one upload target returned to the client.
type InitItemOutput struct {
	ClientRef string            `json:"clientRef"`
	ObjectKey string            `json:"objectKey"`
	UploadURL string            `json:"uploadUrl"`
	Method    string            `json:"method"`
	Headers   map[string]string `json:"headers"`
	ExpiresIn int               `json:"expiresIn"`
}

// InitOutput is the service-layer init response.
type InitOutput struct {
	UploadID string           `json:"uploadId"`
	STS      STSCredentials   `json:"sts"`
	Items    []InitItemOutput `json:"items"`
}

// CompleteInput is the service-layer complete request.
type CompleteInput struct {
	UserID   string
	UploadID string
}

// CompleteItemOutput is metadata for a completed upload item.
type CompleteItemOutput struct {
	ClientRef string `json:"clientRef"`
	ObjectKey string `json:"objectKey"`
	SHA256    string `json:"sha256,omitempty"`
	Size      int64  `json:"size,omitempty"`
	Mime      string `json:"mime,omitempty"`
}

// CompleteOutput is the service-layer complete response.
type CompleteOutput struct {
	UploadID string               `json:"uploadId"`
	Status   string               `json:"status"`
	Items    []CompleteItemOutput `json:"items"`
}

// ObjectKeyBuilder generates storage keys by purpose.
type ObjectKeyBuilder struct {
	cfg *config.Config
}

// NewObjectKeyBuilder creates a key builder from service config.
func NewObjectKeyBuilder(cfg *config.Config) *ObjectKeyBuilder {
	return &ObjectKeyBuilder{cfg: cfg}
}

// Build returns the object key for one upload item.
func (b *ObjectKeyBuilder) Build(purpose model.Purpose, userID, familyID, uploadID, clientRef, mime string) string {
	ext := extFromMime(mime)
	safeRef := sanitizeObjectPart(clientRef)
	switch purpose {
	case model.PurposeAIInput:
		return "ai-tmp/" + sanitizeObjectPart(userID) + "/" + uploadID + "/" + safeRef + ext
	case model.PurposePostItem:
		return "family/" + sanitizeObjectPart(familyID) + "/pending/" + uploadID + "/" + safeRef + ext
	default:
		return "unknown/" + uploadID + "/" + safeRef + ext
	}
}

// UploadURL builds the client PUT target for an object key.
func (b *ObjectKeyBuilder) UploadURL(objectKey string) string {
	if b.cfg.MockOSSBaseURL != "" {
		base := strings.TrimRight(b.cfg.MockOSSBaseURL, "/")
		return base + "/put/" + objectKey
	}
	base := strings.TrimRight(b.cfg.OSSEndpoint, "/")
	return base + "/" + b.cfg.OSSBucket + "/" + objectKey
}

func extFromMime(mime string) string {
	switch strings.ToLower(strings.TrimSpace(mime)) {
	case "image/jpeg", "image/jpg":
		return ".jpg"
	case "image/heic":
		return ".heic"
	case "image/png":
		return ".png"
	case "video/mp4":
		return ".mp4"
	case "video/quicktime":
		return ".mov"
	default:
		if idx := strings.LastIndex(mime, "/"); idx >= 0 && idx < len(mime)-1 {
			return "." + mime[idx+1:]
		}
		return ".bin"
	}
}

func sanitizeObjectPart(part string) string {
	part = strings.TrimSpace(part)
	part = strings.ReplaceAll(part, "..", "")
	part = strings.ReplaceAll(part, "/", "_")
	if part == "" {
		return "unknown"
	}
	return part
}
