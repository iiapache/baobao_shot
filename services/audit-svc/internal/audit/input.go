package audit

import (
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

const inputVendorName = "aliyun-green"

// NewInputPipeline creates the AI input audit pipeline (sync, <=3s in T3.4).
func NewInputPipeline(st store.AuditStore, vendor Vendor) AuditPipeline {
	if vendor == nil {
		vendor = StubVendor{}
	}
	return newBasePipeline(model.AuditKindInput, inputVendorName, st, vendor)
}
