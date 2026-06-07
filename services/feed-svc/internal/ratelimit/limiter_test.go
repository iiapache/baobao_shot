package ratelimit

import (
	"testing"
	"time"
)

func TestSlidingWindowAllow(t *testing.T) {
	limiter := NewSlidingWindow()
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	cfg := Config{Window: time.Minute, Max: 5}

	for i := 0; i < 5; i++ {
		if !limiter.Allow("usr_1", now.Add(time.Duration(i)*time.Second), cfg) {
			t.Fatalf("request %d should be allowed", i+1)
		}
	}
	if limiter.Allow("usr_1", now.Add(5*time.Second), cfg) {
		t.Fatal("6th request should be denied")
	}
	if limiter.Count("usr_1", now.Add(5*time.Second), cfg.Window) != 5 {
		t.Fatal("count should be 5 within window")
	}
	if !limiter.Allow("usr_2", now, cfg) {
		t.Fatal("different key should be allowed")
	}
}
