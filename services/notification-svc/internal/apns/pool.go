package apns

import "context"

// pool holds connection metadata for one deployment region.
type pool struct {
	region Region
	host   string
}

// newPool creates a region-scoped APNs pool stub (HTTP/2 connections deferred to live mode).
func newPool(region Region, sandbox bool) (*pool, error) {
	switch region {
	case RegionCN, RegionOS:
		host := HostProduction
		if sandbox {
			host = HostSandbox
		}
		return &pool{region: region, host: host}, nil
	default:
		return nil, ErrUnsupportedRegion
	}
}

func (p *pool) hostForSend() string {
	if p == nil {
		return HostProduction
	}
	return p.host
}

// noopPoolPing validates pool readiness without opening real connections.
func (p *pool) ping(_ context.Context) error {
	if p == nil {
		return ErrUnsupportedRegion
	}
	return nil
}
