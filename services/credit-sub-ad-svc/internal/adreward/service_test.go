package adreward_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
)

const testSecret = "mock-pangle-secret"

func newTestService(t *testing.T, fixed time.Time) (*adreward.Service, store.Store) {
	t.Helper()
	st := store.NewMemoryStore()
	ledger := credit.NewService(st)
	registry := adreward.NewRegistry(testSecret, "")
	registry.Register(adreward.NewHMACVerifier(adreward.NetworkAdMob, testSecret))
	svc := adreward.NewService(st, ledger, registry, adreward.Options{
		MinInterval: 0,
	})
	svc.SetFreqGuard(adreward.NewFreqGuard(0, adreward.DefaultDailyLimit))
	svc.SetNow(func() time.Time { return fixed })
	nonce := adreward.NewNonceGuard()
	nonce.SetNow(func() time.Time { return fixed })
	svc.SetNonceGuard(nonce)
	return svc, st
}

func TestAllianceCallbackGrantsCredits(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _ := newTestService(t, fixed)
	sign := adreward.ComputeHMACSign(testSecret, "mock-trans-001", "usr_ad_1")

	result, err := svc.AllianceCallback(context.Background(), adreward.AllianceRequest{
		Network:     adreward.NetworkPangle,
		UserID:      "usr_ad_1",
		PlacementID: "slot_1",
		TransID:     "mock-trans-001",
		Sign:        sign,
	})
	if err != nil {
		t.Fatalf("AllianceCallback() error = %v", err)
	}
	if result.GrantedCredits != adreward.DefaultCreditsPerReward {
		t.Fatalf("granted = %d, want %d", result.GrantedCredits, adreward.DefaultCreditsPerReward)
	}
	if result.BalanceAfter != adreward.DefaultCreditsPerReward {
		t.Fatalf("balance = %d", result.BalanceAfter)
	}
}

func TestAllianceCallbackRejectsForgedSignature(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _ := newTestService(t, fixed)

	_, err := svc.AllianceCallback(context.Background(), adreward.AllianceRequest{
		Network:     adreward.NetworkPangle,
		UserID:      "usr_ad_2",
		PlacementID: "slot_1",
		TransID:     "mock-trans-002",
		Sign:        "deadbeef",
	})
	if err == nil {
		t.Fatal("expected signature error")
	}
	if err != adreward.ErrInvalidSignature {
		t.Fatalf("error = %v, want ErrInvalidSignature", err)
	}
}

func TestAllianceCallbackDuplicateIsIdempotent(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _ := newTestService(t, fixed)
	sign := adreward.ComputeHMACSign(testSecret, "mock-trans-dup", "usr_ad_dup")
	req := adreward.AllianceRequest{
		Network:     adreward.NetworkPangle,
		UserID:      "usr_ad_dup",
		PlacementID: "slot_1",
		TransID:     "mock-trans-dup",
		Sign:        sign,
	}

	first, err := svc.AllianceCallback(context.Background(), req)
	if err != nil {
		t.Fatalf("first callback error = %v", err)
	}
	second, err := svc.AllianceCallback(context.Background(), req)
	if err != nil {
		t.Fatalf("second callback error = %v", err)
	}
	if !second.Duplicate {
		t.Fatalf("duplicate = false")
	}
	if second.GrantedCredits != 0 {
		t.Fatalf("second granted = %d", second.GrantedCredits)
	}
	if second.BalanceAfter != first.BalanceAfter {
		t.Fatalf("balance changed on duplicate")
	}
}

func TestClientReportRequiresIDFV(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _ := newTestService(t, fixed)

	_, err := svc.ClientReport(context.Background(), adreward.ClientRequest{
		UserID:      "usr_client",
		Network:     adreward.NetworkPangle,
		PlacementID: "slot_1",
		TransID:     "client-trans-1",
		Nonce:       "nonce-1",
		TimestampMs: fixed.UnixMilli(),
	})
	if err != adreward.ErrInvalidRequest {
		t.Fatalf("error = %v, want ErrInvalidRequest", err)
	}
}

func TestDailyLimitFivePerUser(t *testing.T) {
	fixed := time.Date(2026, 6, 6, 10, 0, 0, 0, time.UTC)
	svc, _ := newTestService(t, fixed)

	for i := 0; i < adreward.DefaultDailyLimit; i++ {
		transID := fmt.Sprintf("daily-trans-%d", i)
		sign := adreward.ComputeHMACSign(testSecret, transID, "usr_daily")
		if _, err := svc.AllianceCallback(context.Background(), adreward.AllianceRequest{
			Network:     adreward.NetworkPangle,
			UserID:      "usr_daily",
			PlacementID: "slot_1",
			TransID:     transID,
			Sign:        sign,
		}); err != nil {
			t.Fatalf("callback %d error = %v", i, err)
		}
	}

	sign := adreward.ComputeHMACSign(testSecret, "daily-trans-overflow", "usr_daily")
	_, err := svc.AllianceCallback(context.Background(), adreward.AllianceRequest{
		Network:     adreward.NetworkPangle,
		UserID:      "usr_daily",
		PlacementID: "slot_1",
		TransID:     "daily-trans-overflow",
		Sign:        sign,
	})
	if err != adreward.ErrDailyLimit {
		t.Fatalf("error = %v, want ErrDailyLimit", err)
	}
}
