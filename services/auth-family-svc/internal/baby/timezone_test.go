package baby_test

import (
	"testing"

	"github.com/baobao/auth-family-svc/internal/baby"
)

func TestResolveTimezoneFromBirthPlace(t *testing.T) {
	place := "北京"
	got := baby.ResolveTimezone(&place, "America/New_York")
	if got != "Asia/Shanghai" {
		t.Fatalf("timezone = %q, want Asia/Shanghai", got)
	}
}

func TestResolveTimezoneFromDevice(t *testing.T) {
	got := baby.ResolveTimezone(nil, "Asia/Tokyo")
	if got != "Asia/Tokyo" {
		t.Fatalf("timezone = %q, want Asia/Tokyo", got)
	}
}

func TestResolveTimezoneFallbackUTC(t *testing.T) {
	place := "未知城市"
	got := baby.ResolveTimezone(&place, "not-a-zone")
	if got != "UTC" {
		t.Fatalf("timezone = %q, want UTC", got)
	}
}

func TestResolveTimezoneIANAPlace(t *testing.T) {
	place := "Europe/Paris"
	got := baby.ResolveTimezone(&place, "Asia/Shanghai")
	if got != "Europe/Paris" {
		t.Fatalf("timezone = %q, want Europe/Paris", got)
	}
}
