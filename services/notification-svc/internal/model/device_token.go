package model

import "time"

// DeviceToken is a registered APNs device for push delivery.
type DeviceToken struct {
	UserID     string    `json:"userId"`
	DeviceID   string    `json:"deviceId"`
	APNSToken  string    `json:"apnsToken"`
	Region     string    `json:"region"`
	AppVersion string    `json:"appVersion,omitempty"`
	OSVersion  string    `json:"osVersion,omitempty"`
	Model      string    `json:"model,omitempty"`
	UpdatedAt  time.Time `json:"updatedAt"`
}
