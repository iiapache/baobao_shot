package product

import (
	_ "embed"
	"fmt"

	"gopkg.in/yaml.v3"
)

//go:embed product-config.yaml
var configYAML []byte

// Config is the published V1.0 product parameter snapshot.
type Config struct {
	Version   string `json:"version" yaml:"version"`
	DecidedAt string `json:"decidedAt" yaml:"decided_at"`
	Status    string `json:"status" yaml:"status"`
	Notes     string `json:"notes,omitempty" yaml:"notes,omitempty"`

	Family         FamilyLimits         `json:"family" yaml:"family"`
	Invite         InviteRules          `json:"invite" yaml:"invite"`
	AdminTakeover  AdminTakeoverRules   `json:"adminTakeover" yaml:"admin_takeover"`
	Credits        CreditRules          `json:"credits" yaml:"credits"`
	RechargePacks  []RechargePack       `json:"rechargePacks" yaml:"recharge_packs"`
	Subscription   []SubscriptionTier   `json:"subscriptionTiers" yaml:"subscription_tiers"`
	AIPricing      AIPricingSnapshot    `json:"aiPricing" yaml:"ai_pricing"`
	AIVideo        AIVideoRules         `json:"aiVideo" yaml:"ai_video"`
	ScopeV1        ScopeV1              `json:"scopeV1" yaml:"scope_v1"`
}

type FamilyLimits struct {
	MaxMembers                int `json:"maxMembers" yaml:"max_members"`
	MaxBabies                 int `json:"maxBabies" yaml:"max_babies"`
	MaxFamiliesCreatedPerUser int `json:"maxFamiliesCreatedPerUser" yaml:"max_families_created_per_user"`
	MaxFamiliesJoinedPerUser  int `json:"maxFamiliesJoinedPerUser" yaml:"max_families_joined_per_user"`
}

type InviteRules struct {
	CodeLength int `json:"codeLength" yaml:"code_length"`
	TTLHours   int `json:"ttlHours" yaml:"ttl_hours"`
	MaxUses    int `json:"maxUses" yaml:"max_uses"`
}

type AdminTakeoverRules struct {
	InactiveDays    int     `json:"inactiveDays" yaml:"inactive_days"`
	ApprovalRatio   float64 `json:"approvalRatio" yaml:"approval_ratio"`
	ObjectionDays   int     `json:"objectionDays" yaml:"objection_days"`
}

type CreditRules struct {
	Signup             int `json:"signup" yaml:"signup"`
	ProfileComplete    int `json:"profileComplete" yaml:"profile_complete"`
	InviteReward       int `json:"inviteReward" yaml:"invite_reward"`
	SignInMin          int `json:"signInMin" yaml:"sign_in_min"`
	SignInMax          int `json:"signInMax" yaml:"sign_in_max"`
	AdRewardPerView    int `json:"adRewardPerView" yaml:"ad_reward_per_view"`
	AdRewardDailyLimit int `json:"adRewardDailyLimit" yaml:"ad_reward_daily_limit"`
	CaptionDailyLimit  int `json:"captionDailyLimit" yaml:"caption_daily_limit"`
}

type RechargePack struct {
	ProductID string `json:"productId" yaml:"product_id"`
	Credits   int    `json:"credits" yaml:"credits"`
	PriceCNY  int    `json:"priceCny" yaml:"price_cny"`
}

type SubscriptionTier struct {
	SKU           string `json:"sku" yaml:"sku"`
	PriceCNY      int    `json:"priceCny" yaml:"price_cny"`
	BonusCredits  int    `json:"bonusCredits" yaml:"bonus_credits"`
}

type AIPricingSnapshot struct {
	RatesManifestVersion string         `json:"ratesManifestVersion" yaml:"rates_manifest_version"`
	Plays                map[string]int `json:"plays" yaml:"plays"`
}

type AIVideoRules struct {
	DurationTiersSeconds []int `json:"durationTiersSeconds" yaml:"duration_tiers_seconds"`
	TrialDurationSeconds *int  `json:"trialDurationSeconds" yaml:"trial_duration_seconds"`
}

type ScopeV1 struct {
	PregnancyMode            bool     `json:"pregnancyMode" yaml:"pregnancy_mode"`
	WidgetSizes              []string `json:"widgetSizes" yaml:"widget_sizes"`
	DataExportFormats        []string `json:"dataExportFormats" yaml:"data_export_formats"`
	WechatShareScope         []string `json:"wechatShareScope" yaml:"wechat_share_scope"`
	DeferredPlatforms        []string `json:"deferredPlatforms" yaml:"deferred_platforms"`
	OverseasOriginalToOpenAI bool     `json:"overseasOriginalToOpenAI" yaml:"overseas_original_to_openai"`
}

// Load parses the embedded product config manifest.
func Load() (Config, error) {
	var cfg Config
	if err := yaml.Unmarshal(configYAML, &cfg); err != nil {
		return Config{}, fmt.Errorf("parse product config: %w", err)
	}
	if cfg.Version == "" {
		return Config{}, fmt.Errorf("product config missing version")
	}
	return cfg, nil
}
