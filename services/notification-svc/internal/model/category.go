package model

// Notification categories (design-ios §10.1).
const (
	CategoryMilestone       = "MILESTONE"
	CategoryFamilyActivity  = "FAMILY_ACTIVITY"
	CategoryAIDone          = "AI_DONE"
	CategoryCredit          = "CREDIT"
	CategorySystem          = "SYSTEM"
)

// AllCategories is the canonical category list for subscriptions.
var AllCategories = []string{
	CategoryMilestone,
	CategoryFamilyActivity,
	CategoryAIDone,
	CategoryCredit,
	CategorySystem,
}

// DefaultSubscriptionEnabled returns the default on/off state for a category.
func DefaultSubscriptionEnabled(category string) bool {
	return category != CategorySystem
}

// ValidCategory reports whether category is a known notification category.
func ValidCategory(category string) bool {
	for _, c := range AllCategories {
		if c == category {
			return true
		}
	}
	return false
}
