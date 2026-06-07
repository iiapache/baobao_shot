package worker

import (
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const (
	// ImageInvokeTimeout is the model invoke ceiling for image tasks (design-backend §5.5).
	ImageInvokeTimeout = 60 * time.Second
	// VideoInvokeTimeout is the model invoke ceiling for video tasks (design-backend §5.5).
	VideoInvokeTimeout = 300 * time.Second
)

// InvokeTimeout returns the per-invoke deadline for a task capability.
func InvokeTimeout(capability model.Capability) time.Duration {
	if capability == model.CapabilityVideoGen {
		return VideoInvokeTimeout
	}
	return ImageInvokeTimeout
}
