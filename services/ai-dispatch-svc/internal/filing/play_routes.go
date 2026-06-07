package filing

// CNPlayAdapters maps play manifest IDs to CN adapter candidates (design-backend §5.3).
// Plays absent from this map are not gated by CN algorithm filing (e.g. text-only plays).
var CNPlayAdapters = map[string][]string{
	"ghibli_kid":        {"SeedreamAdapter", "TongyiWanxiangAdapter"},
	"seedream_style":    {"SeedreamAdapter"},
	"photo_restore":     {"TongyiWanxiangAdapter", "JimengAdapter"},
	"video_walk":        {"SeedanceAdapter"},
	"year_review_regen": {"SeedanceAdapter"},
}
