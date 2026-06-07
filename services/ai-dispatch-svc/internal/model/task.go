package model

import "time"

// Region identifies the deployment / user region for routing.
type Region string

const (
	RegionCN Region = "cn"
	RegionOS Region = "os"
)

// Capability describes the AI task output type.
type Capability string

const (
	CapabilityImageEdit Capability = "image-edit"
	CapabilityImageGen  Capability = "image-gen"
	CapabilityVideoGen  Capability = "video-gen"
)

// TaskInput holds uploaded source object metadata.
type TaskInput struct {
	ObjectKey string `bson:"objectKey" json:"objectKey"`
	SHA256    string `bson:"sha256" json:"sha256"`
}

// TaskOutput holds generated artifact object keys.
type TaskOutput struct {
	ObjectKey     string `bson:"objectKey,omitempty" json:"objectKey,omitempty"`
	ThumbnailKey  string `bson:"thumbnailKey,omitempty" json:"thumbnailKey,omitempty"`
}

// AuditResult tracks input/output moderation outcomes.
type AuditResult struct {
	Input  string `bson:"input,omitempty" json:"input,omitempty"`
	Output string `bson:"output,omitempty" json:"output,omitempty"`
}

// DeepSynthMetadata records watermark and manifest versions.
type DeepSynthMetadata struct {
	Watermark string `bson:"watermark,omitempty" json:"watermark,omitempty"`
	Manifest  string `bson:"manifest,omitempty" json:"manifest,omitempty"`
}

// StateHistoryEntry records a single state transition timestamp.
type StateHistoryEntry struct {
	State string    `bson:"state" json:"state"`
	At    time.Time `bson:"at" json:"at"`
}

// ModelInvocation records a vendor call attempt.
type ModelInvocation struct {
	Vendor    string `bson:"vendor" json:"vendor"`
	LatencyMs int64  `bson:"latencyMs" json:"latencyMs"`
	Retry     int    `bson:"retry" json:"retry"`
}

// Task is the MongoDB ai_tasks collection document (design-backend §4.2).
type Task struct {
	ID               string              `bson:"_id" json:"id"`
	UserID           string              `bson:"userId" json:"userId"`
	Region           Region              `bson:"region" json:"region"`
	Style            string              `bson:"style" json:"style"`
	Model            string              `bson:"model,omitempty" json:"model,omitempty"`
	Capability       Capability          `bson:"capability" json:"capability"`
	Input            TaskInput           `bson:"input" json:"input"`
	Output           TaskOutput          `bson:"output,omitempty" json:"output,omitempty"`
	Audit            AuditResult         `bson:"audit,omitempty" json:"audit,omitempty"`
	DeepSynth        DeepSynthMetadata   `bson:"deepSynth,omitempty" json:"deepSynth,omitempty"`
	State            string              `bson:"state" json:"state"`
	StateHistory     []StateHistoryEntry `bson:"stateHistory" json:"stateHistory"`
	CostCredits      int                 `bson:"costCredits" json:"costCredits"`
	CreditHoldID     string              `bson:"creditHoldId,omitempty" json:"creditHoldId,omitempty"`
	ModelInvocations []ModelInvocation   `bson:"modelInvocations,omitempty" json:"modelInvocations,omitempty"`
	ModelRetryCount  int                 `bson:"modelRetryCount,omitempty" json:"modelRetryCount,omitempty"`
	CreatedAt        time.Time           `bson:"createdAt" json:"createdAt"`
	UpdatedAt        time.Time           `bson:"updatedAt" json:"updatedAt"`
}

// CollectionName is the MongoDB collection for AI tasks.
const CollectionName = "ai_tasks"
