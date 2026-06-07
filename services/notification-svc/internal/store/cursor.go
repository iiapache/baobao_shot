package store

import (
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/model"
)

// ErrInvalidCursor is returned when a pagination cursor cannot be decoded.
var ErrInvalidCursor = fmt.Errorf("invalid pagination cursor")

// ParseNotificationCursor decodes a notification pagination cursor.
func ParseNotificationCursor(cursor string) (createdAt time.Time, id string, err error) {
	cursor = strings.TrimSpace(cursor)
	if cursor == "" {
		return time.Time{}, "", nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 || parts[1] == "" {
		return time.Time{}, "", ErrInvalidCursor
	}
	createdAt, err = time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	return createdAt.UTC(), parts[1], nil
}

// EncodeNotificationCursor builds an opaque cursor from a notification.
func EncodeNotificationCursor(n model.Notification) string {
	payload := n.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + n.ID
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

// NormalizeNotificationLimit clamps page size to API bounds (50/page per T5.8).
func NormalizeNotificationLimit(limit int) int {
	if limit <= 0 {
		return defaultNotificationPageSize
	}
	if limit > maxNotificationPageSize {
		return maxNotificationPageSize
	}
	return limit
}
