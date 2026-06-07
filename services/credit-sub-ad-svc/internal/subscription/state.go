package subscription

import (
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// EventType drives subscription state transitions.
type EventType string

const (
	EventPurchase       EventType = "purchase"
	EventRenew          EventType = "renew"
	EventRenewalFailed  EventType = "renewal_failed"
	EventGraceExpired   EventType = "grace_expired"
	EventPeriodEnded    EventType = "period_ended"
	EventRefund         EventType = "refund"
	EventRepurchase     EventType = "repurchase"
)

// DefaultGracePeriod is Apple's billing retry window used by cron fallback.
const DefaultGracePeriod = 16 * 24 * time.Hour

// NextState returns the target state for a transition event.
func NextState(current model.SubscriptionState, event EventType) (model.SubscriptionState, error) {
	switch event {
	case EventPurchase:
		switch current {
		case "":
			return model.SubscriptionActive, nil
		default:
			return "", ErrInvalidTransition
		}
	case EventRenew:
		switch current {
		case model.SubscriptionTrial, model.SubscriptionActive, model.SubscriptionGrace:
			return model.SubscriptionActive, nil
		default:
			return "", ErrInvalidTransition
		}
	case EventRenewalFailed:
		if current == model.SubscriptionActive {
			return model.SubscriptionGrace, nil
		}
		return "", ErrInvalidTransition
	case EventGraceExpired:
		if current == model.SubscriptionGrace {
			return model.SubscriptionExpired, nil
		}
		return "", ErrInvalidTransition
	case EventPeriodEnded:
		switch current {
		case model.SubscriptionActive, model.SubscriptionTrial:
			return model.SubscriptionExpired, nil
		default:
			return "", ErrInvalidTransition
		}
	case EventRefund:
		switch current {
		case model.SubscriptionTrial, model.SubscriptionActive, model.SubscriptionGrace:
			return model.SubscriptionRefunded, nil
		default:
			return "", ErrInvalidTransition
		}
	case EventRepurchase:
		if current == model.SubscriptionExpired {
			return model.SubscriptionActive, nil
		}
		return "", ErrInvalidTransition
	default:
		return "", ErrInvalidTransition
	}
}

// InitialStateForPurchase returns trial or active for a first purchase.
func InitialStateForPurchase(isTrial bool) model.SubscriptionState {
	if isTrial {
		return model.SubscriptionTrial
	}
	return model.SubscriptionActive
}

// CronEventForSubscription decides which expiry event cron should apply.
func CronEventForSubscription(sub model.Subscription, now time.Time, gracePeriod time.Duration) (EventType, bool) {
	if gracePeriod <= 0 {
		gracePeriod = DefaultGracePeriod
	}
	if !now.After(sub.PeriodEnd) {
		return "", false
	}

	switch sub.State {
	case model.SubscriptionGrace:
		graceDeadline := sub.PeriodEnd.Add(gracePeriod)
		if now.After(graceDeadline) || now.Equal(graceDeadline) {
			return EventGraceExpired, true
		}
		return "", false
	case model.SubscriptionActive:
		if sub.AutoRenew {
			return EventRenewalFailed, true
		}
		return EventPeriodEnded, true
	case model.SubscriptionTrial:
		if sub.AutoRenew {
			return EventRenewalFailed, true
		}
		return EventPeriodEnded, true
	default:
		return "", false
	}
}
