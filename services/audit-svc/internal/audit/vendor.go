package audit

import (
	"context"

	"github.com/baobao/audit-svc/internal/model"
)

// VendorRequest is the normalized vendor audit payload.
type VendorRequest struct {
	Kind      model.AuditKind
	TargetRef string
	Region    string
	MediaType string
	ObjectKey string
	Text      string
}

// Vendor performs third-party content moderation.
type Vendor interface {
	Audit(ctx context.Context, req VendorRequest) (passed bool, reasons []string, err error)
}

// StubVendor always passes in skeleton mode.
type StubVendor struct{}

// Audit returns passed with no reasons.
func (StubVendor) Audit(_ context.Context, _ VendorRequest) (bool, []string, error) {
	return true, nil, nil
}
