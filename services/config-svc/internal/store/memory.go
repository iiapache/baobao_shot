package store

import "github.com/baobao/config-svc/internal/feature"

// MemoryStore holds seed config in process memory.
type MemoryStore struct {
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
					Key:            "backup.baidu_netdisk",
					DefaultEnabled: true,
					Regions:        []string{"cn"},
					RolloutPercent: 50,
				},
				{
					Key:            "iap.os_storekit2",
					DefaultEnabled: true,
					Regions:        []string{"os"},
					RolloutPercent: 100,
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
	return s.snapshot
}
