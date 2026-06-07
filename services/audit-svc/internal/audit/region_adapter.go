package audit

import "context"

const (
	RegionCN = "cn"
	RegionOS = "os"
)

// RegionVendorAdapter routes audit calls to region-specific vendors without cross-region invocation.
type RegionVendorAdapter struct {
	DeployRegion string
	CN           Vendor
	OS           Vendor
}

// NewRegionVendorAdapter wires CN/OS vendors for dual-region deployment.
func NewRegionVendorAdapter(deployRegion string, cn, os Vendor) *RegionVendorAdapter {
	if cn == nil {
		cn = StubVendor{}
	}
	if os == nil {
		os = StubVendor{}
	}
	return &RegionVendorAdapter{
		DeployRegion: normalizeRegion(deployRegion),
		CN:           cn,
		OS:           os,
	}
}

// Audit delegates to the vendor for req.Region after deploy-region validation.
func (a *RegionVendorAdapter) Audit(ctx context.Context, req VendorRequest) (bool, []string, error) {
	region := normalizeRegion(req.Region)
	if region != RegionCN && region != RegionOS {
		return false, nil, ErrInvalidRegion
	}
	if a.DeployRegion != "" && region != a.DeployRegion {
		return false, nil, ErrRegionMismatch
	}

	switch region {
	case RegionCN:
		return a.CN.Audit(ctx, req)
	case RegionOS:
		return a.OS.Audit(ctx, req)
	default:
		return false, nil, ErrInvalidRegion
	}
}
