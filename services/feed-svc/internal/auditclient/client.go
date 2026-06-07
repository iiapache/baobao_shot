package auditclient

import "context"

// TextAuditRequest is the payload for synchronous UGC text moderation.
type TextAuditRequest struct {
	TargetRef string
	Region    string
	Text      string
}

// MediaAuditRequest is the payload for async UGC media moderation.
type MediaAuditRequest struct {
	TargetRef string
	Region    string
	MediaType string
	ObjectKey string
}

// Result is the normalized moderation outcome.
type Result struct {
	JobID   string
	Passed  bool
	Reasons []string
}

// Client performs feed UGC audits (text sync, media async).
type Client interface {
	AuditTextSync(ctx context.Context, req TextAuditRequest) (Result, error)
	EnqueueMediaAsync(ctx context.Context, req MediaAuditRequest) (Result, error)
}
