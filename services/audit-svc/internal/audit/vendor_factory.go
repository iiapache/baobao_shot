package audit

import (
	"github.com/baobao/audit-svc/internal/audit/aliyun"
	"github.com/baobao/audit-svc/internal/config"
)

// NewVendorFromConfig builds the region-routed vendor for the running cluster.
func NewVendorFromConfig(cfg *config.Config) Vendor {
	deployRegion := RegionCN
	if cfg != nil && cfg.DeployRegion != "" {
		deployRegion = cfg.DeployRegion
	}
	return NewRegionVendorAdapter(
		deployRegion,
		NewCNVendor(cfg),
		NewOSVendorAdapter(DefaultOSStubs()),
	)
}

// NewCNVendor returns the CN content security vendor from runtime config.
func NewCNVendor(cfg *config.Config) Vendor {
	if cfg == nil || !cfg.AliyunGreenEnabled() {
		return StubVendor{}
	}
	adapter := aliyun.NewContentSecurityAdapter(aliyun.Config{
		MockMode:        cfg.AliyunGreenMockMode,
		AccessKeyID:     cfg.AliyunGreenAccessKeyID,
		AccessKeySecret: cfg.AliyunGreenAccessKeySecret,
		Region:          cfg.AliyunGreenRegion,
		Endpoint:        cfg.AliyunGreenEndpoint,
		ObjectURLPrefix: cfg.AliyunGreenObjectURLPrefix,
		ImageScenes:     cfg.AliyunGreenImageScenes,
		TextScenes:      cfg.AliyunGreenTextScenes,
	})
	return aliyunVendor{inner: adapter}
}
