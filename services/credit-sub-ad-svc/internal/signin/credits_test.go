package signin

import "testing"

func TestCreditsForStreak(t *testing.T) {
	tests := []struct {
		streak int
		want   int64
	}{
		{1, 5},
		{2, 6},
		{10, 14},
		{16, 20},
		{17, 20},
		{30, 20},
		{0, 5},
	}
	for _, tc := range tests {
		if got := CreditsForStreak(tc.streak); got != tc.want {
			t.Fatalf("CreditsForStreak(%d) = %d, want %d", tc.streak, got, tc.want)
		}
	}
}
