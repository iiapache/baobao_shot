package model

// NotificationSubscription is a per-user category toggle.
type NotificationSubscription struct {
	Category string `json:"category"`
	Enabled  bool   `json:"enabled"`
}
