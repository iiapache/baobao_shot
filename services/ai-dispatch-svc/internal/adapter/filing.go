package adapter

import "github.com/baobao/ai-dispatch-svc/internal/model"

// FilingInfo binds CN algorithm filing numbers to an adapter (T7.1).
type FilingInfo struct {
	GenAIFilingNo     string
	DeepSynthFilingNo string
}

// IsValid reports whether the adapter may be routed for the given region.
// CN adapters require both filing numbers; OS adapters are exempt from CN filing.
func (f FilingInfo) IsValid(region model.Region) bool {
	if region == model.RegionOS {
		return true
	}
	return f.GenAIFilingNo != "" && f.DeepSynthFilingNo != ""
}
