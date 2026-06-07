package audit

import (
	"github.com/baobao/audit-svc/internal/model"
	"github.com/baobao/audit-svc/internal/store"
)

const outputVendorName = "aliyun-green"

// NewOutputPipeline creates the AI output audit pipeline (sync, <=5s in T3.4).
func NewOutputPipeline(st store.AuditStore, vendor Vendor) AuditPipeline {
	if vendor == nil {
		vendor = StubVendor{}
	}
	return newBasePipeline(model.AuditKindOutput, outputVendorName, st, vendor)
}
