package orchestrator

import "github.com/baobao/notification-svc/internal/model"

// PushPriority returns APNs priority for a notification category (design-backend §8).
func PushPriority(category string) int {
	switch category {
	case model.CategoryAIDone, model.CategoryCredit, model.CategoryFamilyActivity:
		return 10
	default:
		return 5
	}
}
