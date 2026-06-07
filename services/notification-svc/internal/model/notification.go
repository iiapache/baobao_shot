package model

import (
	"encoding/json"
	"time"
)

// Notification is an in-app message center entry.
type Notification struct {
	ID        string          `json:"id"`
	UserID    string          `json:"-"`
	Category  string          `json:"category"`
	Payload   json.RawMessage `json:"payload"`
	ReadAt    *time.Time      `json:"readAt,omitempty"`
	CreatedAt time.Time       `json:"createdAt"`
}
