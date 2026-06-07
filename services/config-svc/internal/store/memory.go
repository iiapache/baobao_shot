package store

import (
	"fmt"
	"sync"

	"github.com/baobao/config-svc/internal/feature"
)

// MemoryStore holds seed config in process memory.
type MemoryStore struct {
	mu       sync.RWMutex
	snapshot Snapshot
}

// NewMemoryStore returns the default in-memory config catalog.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		snapshot: Snapshot{
			Version: "20250606001",
			Features: []feature.Definition{
				{
					Key:            "editor.remote_templates",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "v1",
				},
				{
					Key:            "ai.storybook",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 30,
					Variant:        "beta",
				},
				{
					Key:            "feed.family_alpha",
					DefaultEnabled: true,
					RolloutPercent: 10,
					MinAppVersion:  "1.2.0",
				},
				{
					Key:            "compliance.icp_number",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "{{ICP_NUMBER}}",
				},
				{
					Key:            "compliance.algorithm_filing_summary",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "算法备案办理中（DEV 占位）",
				},
				{
					Key:            "compliance.policy_urls.privacy_cn",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "https://www.babycamera.app/legal/privacy-policy-cn",
				},
				{
					Key:            "compliance.policy_urls.privacy_os",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
					Variant:        "https://www.babycamera.app/legal/privacy-policy-os",
				},
				{
					Key:            "compliance.policy_urls.terms_cn",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "https://www.babycamera.app/legal/terms-of-service",
				},
				{
					Key:            "compliance.policy_urls.deep_synthesis_cn",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "https://www.babycamera.app/legal/deep-synthesis-notice",
				},
				{
					Key:            "compliance.policy_urls.third_party_sdk",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "https://www.babycamera.app/legal/third-party-sdk-list",
				},
				{
					Key:            "compliance.policy_versions.privacy_cn",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "v1.0.0",
				},
				{
					Key:            "compliance.policy_versions.privacy_os",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
					Variant:        "v1.0.0",
				},
				{
					Key:            "compliance.policy_versions.terms",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "v1.0.0",
				},
				{
					Key:            "compliance.policy_versions.deep_synthesis",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
					Variant:        "v1.0.0",
				},
				{
					Key:            "compliance.policy_versions.third_party_sdk",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "v1.0.0",
				},
				{
					Key:            "compliance.support_email",
					DefaultEnabled: true,
					RolloutPercent: 100,
					Variant:        "support@babycamera.app",
				},
				{
					Key:            "backup.baidu_netdisk",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 50,
				},
				{
					Key:            "compliance.os_training_opt_out",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
					Variant:        "contract-v1",
				},
				{
					Key:            "iap.os_storekit2",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.ghibli_kid",
					DefaultEnabled: true,
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.gpt_portrait",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.seedream_style",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.photo_restore",
					DefaultEnabled: true,
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.video_walk",
					DefaultEnabled: true,
					RolloutPercent: 50,
					Variant:        "beta",
				},
				{
					Key:            "ai.play.year_review_regen",
					DefaultEnabled: true,
					RolloutPercent: 100,
				},
				{
					Key:            "ai.play.smart_caption",
					DefaultEnabled: true,
					RolloutPercent: 100,
				},
				// T7.14 — App Store Phased Release 联动灰度（D1 默认 1%）
				{
					Key:            "rollout.ai_plays_percent",
					DefaultEnabled: true,
					RolloutPercent: 1,
					Variant:        "1",
				},
				{
					Key:            "rollout.pricing_variant",
					DefaultEnabled: true,
					RolloutPercent: 50,
					Variant:        "control",
				},
			},
			Plays: []PlayDefinition{
				{
					ID:          "play_storybook",
					Name:        "AI 故事书",
					Description: "百天 / 周岁成长故事（占位）",
					Regions:     []string{"cn"},
					Enabled:     true,
				},
				{
					ID:          "play_cartoon",
					Name:        "卡通头像",
					Description: "宝宝卡通化（占位）",
					Enabled:     true,
				},
			},
		},
	}
}

// GetSnapshot returns the in-memory catalog.
func (s *MemoryStore) GetSnapshot() Snapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.snapshot
}

// FeaturePatch updates a feature flag in memory (T7.14 admin / kill-switch).
type FeaturePatch struct {
	DefaultEnabled *bool
	RolloutPercent *int
	Variant        *string
}

// PlayPatch updates a play catalog entry in memory.
type PlayPatch struct {
	Enabled *bool
}

// PatchFeature applies partial updates to a feature by key.
func (s *MemoryStore) PatchFeature(key string, patch FeaturePatch) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.snapshot.Features {
		if s.snapshot.Features[i].Key != key {
			continue
		}
		if patch.DefaultEnabled != nil {
			s.snapshot.Features[i].DefaultEnabled = *patch.DefaultEnabled
		}
		if patch.RolloutPercent != nil {
			s.snapshot.Features[i].RolloutPercent = *patch.RolloutPercent
		}
		if patch.Variant != nil {
			s.snapshot.Features[i].Variant = *patch.Variant
		}
		return nil
	}
	return fmt.Errorf("feature %q not found", key)
}

// PatchPlay applies partial updates to a play by id.
func (s *MemoryStore) PatchPlay(id string, patch PlayPatch) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.snapshot.Plays {
		if s.snapshot.Plays[i].ID != id {
			continue
		}
		if patch.Enabled != nil {
			s.snapshot.Plays[i].Enabled = *patch.Enabled
		}
		return nil
	}
	return fmt.Errorf("play %q not found", id)
}

// DisableFeature sets defaultEnabled=false and rolloutPercent=0 for emergency kill-switch.
func (s *MemoryStore) DisableFeature(key string) error {
	falseVal := false
	zero := 0
	return s.PatchFeature(key, FeaturePatch{
		DefaultEnabled: &falseVal,
		RolloutPercent: &zero,
	})
}
