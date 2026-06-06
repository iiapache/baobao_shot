package feature

import "hash/fnv"

// UserIDHash returns a stable bucket in [0, 99] for rollout bucketing.
func UserIDHash(userID string) int {
	if userID == "" {
		return 0
	}
	h := fnv.New32a()
	_, _ = h.Write([]byte(userID))
	return int(h.Sum32() % 100)
}
