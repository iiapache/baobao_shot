package adapter

import (
	"context"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// InvokeOutput holds generated artifact keys from a model vendor call.
type InvokeOutput struct {
	ObjectKey    string
	ThumbnailKey string
}

// InvokeRequest is the normalized adapter invocation payload (style + capability + input).
type InvokeRequest struct {
	Style           string
	Capability      model.Capability
	Region          model.Region
	Input           model.TaskInput
	DurationSeconds int // video play tier (5 / 10 for Seedance)
}

// ModelAdapter is the unified vendor integration surface (design-backend §5.2).
type ModelAdapter interface {
	Name() string
	Region() model.Region
	Supports(capability model.Capability) bool
	Cost(req InvokeRequest) int
	Invoke(ctx context.Context, req InvokeRequest) (InvokeOutput, error)
}
