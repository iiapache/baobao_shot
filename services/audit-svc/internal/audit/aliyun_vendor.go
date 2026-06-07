package audit

import (
	"context"

	"github.com/baobao/audit-svc/internal/audit/aliyun"
)

type aliyunVendor struct {
	inner *aliyun.ContentSecurityAdapter
}

func (v aliyunVendor) Audit(ctx context.Context, req VendorRequest) (bool, []string, error) {
	return v.inner.Audit(ctx, aliyun.Request{
		Kind:      string(req.Kind),
		TargetRef: req.TargetRef,
		Region:    req.Region,
		MediaType: req.MediaType,
		ObjectKey: req.ObjectKey,
		Text:      req.Text,
	})
}
