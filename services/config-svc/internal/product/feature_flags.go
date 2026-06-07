package product

import (
	"strconv"

	"github.com/baobao/config-svc/internal/feature"
)

// FeatureDefinitions returns config-svc feature flags derived from product config.
func FeatureDefinitions(cfg Config) []feature.Definition {
	return []feature.Definition{
		{
			Key:            "product.config.version",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        cfg.Version,
		},
		{
			Key:            "product.limits.family_members",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        strconv.Itoa(cfg.Family.MaxMembers),
		},
		{
			Key:            "product.limits.family_babies",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        strconv.Itoa(cfg.Family.MaxBabies),
		},
		{
			Key:            "product.invite.ttl_hours",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        strconv.Itoa(cfg.Invite.TTLHours),
		},
		{
			Key:            "product.invite.max_uses",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        strconv.Itoa(cfg.Invite.MaxUses),
		},
		{
			Key:            "product.credits.signup",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        strconv.Itoa(cfg.Credits.Signup),
		},
		{
			Key:            "product.ai_video.duration_tiers",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        "5,10",
		},
		{
			Key:            "product.scope.pregnancy_mode",
			DefaultEnabled: cfg.ScopeV1.PregnancyMode,
			RolloutPercent: 100,
			Variant:        "v1.1",
		},
		{
			Key:            "product.scope.wechat_share",
			DefaultEnabled: true,
			RolloutPercent: 100,
			Variant:        "moments,friends",
		},
	}
}
