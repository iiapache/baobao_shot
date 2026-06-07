package model

import "time"

// SubscriptionState is the lifecycle state of a subscription.
type SubscriptionState string

const (
	SubscriptionTrial    SubscriptionState = "trial"
	SubscriptionActive   SubscriptionState = "active"
	SubscriptionGrace    SubscriptionState = "grace"
	SubscriptionExpired  SubscriptionState = "expired"
	SubscriptionRefunded SubscriptionState = "refunded"
)

// Subscription persists a user's IAP subscription record.
type Subscription struct {
	ID                      string
	UserID                  string
	OriginalTransactionID   string
	SKU                     string
	PeriodStart             time.Time
	PeriodEnd               time.Time
	State                   SubscriptionState
	AutoRenew               bool
	LastEventAt             time.Time
}

// Entitlements describes subscription-gated product features.
type Entitlements struct {
	RemoveAds               bool `json:"removeAds"`
	BrandWatermarkRemovable bool `json:"brandWatermarkRemovable"`
	AllFilters              bool `json:"allFilters"`
	AnnualReviewRegen       bool `json:"annualReviewRegen"`
}

// EntitlementsForState returns feature flags for a subscription state.
func EntitlementsForState(state SubscriptionState) Entitlements {
	switch state {
	case SubscriptionTrial, SubscriptionActive, SubscriptionGrace:
		return Entitlements{
			RemoveAds:               true,
			BrandWatermarkRemovable: true,
			AllFilters:              true,
			AnnualReviewRegen:       true,
		}
	default:
		return Entitlements{}
	}
}

// IsEntitled reports whether the state grants subscription benefits.
func IsEntitled(state SubscriptionState) bool {
	switch state {
	case SubscriptionTrial, SubscriptionActive, SubscriptionGrace:
		return true
	default:
		return false
	}
}
