package signin

const maxStreakCredits = int64(20)

// CreditsForStreak returns grant amount for a consecutive-day streak (5–20).
func CreditsForStreak(streak int) int64 {
	if streak < 1 {
		streak = 1
	}
	credits := int64(4 + streak)
	if credits > maxStreakCredits {
		return maxStreakCredits
	}
	return credits
}
