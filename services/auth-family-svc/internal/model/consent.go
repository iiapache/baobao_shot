package model

import "time"

// ChildConsent records a user's agreement to the child-data consent document.
type ChildConsent struct {
	UserID   string
	Version  string
	AgreedAt time.Time
	IP       string
	DeviceID string
}
