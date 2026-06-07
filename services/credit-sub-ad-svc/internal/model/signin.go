package model

import "time"

// SignInRecord is one daily sign-in row (design-backend §4.1.3 sign_ins).
type SignInRecord struct {
	UserID         string
	Date           time.Time
	CreditsGranted int64
	Streak         int
}
