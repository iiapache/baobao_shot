package costmetering

import "github.com/baobao/ai-dispatch-svc/internal/model"

// Vendor cost estimates per design-backend §4.11.3 (reverse-calculated from credit pricing).
const (
	imageCNYPerCredit = 0.75 / 8   // 8 credits ≈ ¥0.6–0.8
	videoCNYPerCredit = 4.85 / 60  // 60 credits ≈ ¥4.7–5.0
)

// EstimateVendorCostCNY maps charged credits to estimated vendor spend in yuan.
func EstimateVendorCostCNY(capability model.Capability, costCredits int) float64 {
	if costCredits <= 0 {
		return 0
	}
	rate := imageCNYPerCredit
	if capability == model.CapabilityVideoGen {
		rate = videoCNYPerCredit
	}
	return roundCNY(float64(costCredits) * rate)
}

func roundCNY(v float64) float64 {
	return RoundCNY(v)
}

// RoundCNY rounds yuan values to 4 decimal places.
func RoundCNY(v float64) float64 {
	return float64(int(v*10000+0.5)) / 10000
}
