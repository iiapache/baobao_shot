package costmetering

import (
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

const CollectionName = "cost_metering"

// Record is a single vendor cost observation for one successful model invocation.
type Record struct {
	ID             string           `bson:"_id" json:"id"`
	TaskID         string           `bson:"taskId" json:"taskId"`
	UserID         string           `bson:"userId" json:"userId"`
	Region         model.Region     `bson:"region" json:"region"`
	Style          string           `bson:"style" json:"style"`
	Capability     model.Capability `bson:"capability" json:"capability"`
	Vendor         string           `bson:"vendor" json:"vendor"`
	CostCredits    int              `bson:"costCredits" json:"costCredits"`
	VendorCostCNY  float64          `bson:"vendorCostCNY" json:"vendorCostCNY"`
	LatencyMs      int64            `bson:"latencyMs" json:"latencyMs"`
	Retry          int              `bson:"retry" json:"retry"`
	ReportedAt     time.Time        `bson:"reportedAt" json:"reportedAt"`
}
