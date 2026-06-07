package subscription

import (
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func TestInitialStateForPurchase(t *testing.T) {
	if got := InitialStateForPurchase(true); got != model.SubscriptionTrial {
		t.Fatalf("trial state = %s, want trial", got)
	}
	if got := InitialStateForPurchase(false); got != model.SubscriptionActive {
		t.Fatalf("active state = %s, want active", got)
	}
}

func TestNextStateValidTransitions(t *testing.T) {
	cases := []struct {
		name  string
		from  model.SubscriptionState
		event EventType
		want  model.SubscriptionState
	}{
		{name: "trial to active renew", from: model.SubscriptionTrial, event: EventRenew, want: model.SubscriptionActive},
		{name: "active to active renew", from: model.SubscriptionActive, event: EventRenew, want: model.SubscriptionActive},
		{name: "grace to active renew", from: model.SubscriptionGrace, event: EventRenew, want: model.SubscriptionActive},
		{name: "active to grace renewal failed", from: model.SubscriptionActive, event: EventRenewalFailed, want: model.SubscriptionGrace},
		{name: "grace to expired", from: model.SubscriptionGrace, event: EventGraceExpired, want: model.SubscriptionExpired},
		{name: "active to expired period ended", from: model.SubscriptionActive, event: EventPeriodEnded, want: model.SubscriptionExpired},
		{name: "trial to expired period ended", from: model.SubscriptionTrial, event: EventPeriodEnded, want: model.SubscriptionExpired},
		{name: "active to refunded", from: model.SubscriptionActive, event: EventRefund, want: model.SubscriptionRefunded},
		{name: "trial to refunded", from: model.SubscriptionTrial, event: EventRefund, want: model.SubscriptionRefunded},
		{name: "grace to refunded", from: model.SubscriptionGrace, event: EventRefund, want: model.SubscriptionRefunded},
		{name: "expired to active repurchase", from: model.SubscriptionExpired, event: EventRepurchase, want: model.SubscriptionActive},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := NextState(tc.from, tc.event)
			if err != nil {
				t.Fatalf("NextState() error = %v", err)
			}
			if got != tc.want {
				t.Fatalf("NextState() = %s, want %s", got, tc.want)
			}
		})
	}
}

func TestNextStateInvalidTransitions(t *testing.T) {
	cases := []struct {
		name  string
		from  model.SubscriptionState
		event EventType
	}{
		{name: "expired to grace", from: model.SubscriptionExpired, event: EventRenewalFailed},
		{name: "refunded to active renew", from: model.SubscriptionRefunded, event: EventRenew},
		{name: "expired to refund", from: model.SubscriptionExpired, event: EventRefund},
		{name: "active to repurchase", from: model.SubscriptionActive, event: EventRepurchase},
		{name: "purchase from active", from: model.SubscriptionActive, event: EventPurchase},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := NextState(tc.from, tc.event); err == nil {
				t.Fatal("expected invalid transition error")
			}
		})
	}
}

func TestCronEventForSubscription(t *testing.T) {
	now := time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)
	periodEnd := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)

	cases := []struct {
		name    string
		sub     model.Subscription
		event   EventType
		wantOK  bool
	}{
		{
			name: "active auto renew to grace",
			sub: model.Subscription{State: model.SubscriptionActive, PeriodEnd: periodEnd, AutoRenew: true},
			event: EventRenewalFailed, wantOK: true,
		},
		{
			name: "active no auto renew to expired",
			sub: model.Subscription{State: model.SubscriptionActive, PeriodEnd: periodEnd, AutoRenew: false},
			event: EventPeriodEnded, wantOK: true,
		},
		{
			name: "trial auto renew to grace",
			sub: model.Subscription{State: model.SubscriptionTrial, PeriodEnd: periodEnd, AutoRenew: true},
			event: EventRenewalFailed, wantOK: true,
		},
		{
			name: "grace before deadline noop",
			sub: model.Subscription{State: model.SubscriptionGrace, PeriodEnd: time.Date(2026, 6, 9, 0, 0, 0, 0, time.UTC)},
			wantOK: false,
		},
		{
			name: "grace after deadline to expired",
			sub: model.Subscription{State: model.SubscriptionGrace, PeriodEnd: time.Date(2026, 5, 20, 0, 0, 0, 0, time.UTC)},
			event: EventGraceExpired, wantOK: true,
		},
		{
			name: "not due yet",
			sub: model.Subscription{State: model.SubscriptionActive, PeriodEnd: now.Add(24 * time.Hour)},
			wantOK: false,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			event, ok := CronEventForSubscription(tc.sub, now, DefaultGracePeriod)
			if ok != tc.wantOK {
				t.Fatalf("ok = %v, want %v", ok, tc.wantOK)
			}
			if ok && event != tc.event {
				t.Fatalf("event = %s, want %s", event, tc.event)
			}
		})
	}
}
