package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"
	"time"

	"github.com/baobao/notification-svc/internal/model"
	"github.com/lib/pq"
)

func (s *PostgresStore) InsertNotification(ctx context.Context, in InsertNotificationInput) (*model.Notification, error) {
	payload := in.Payload
	if len(payload) == 0 {
		payload = json.RawMessage(`{}`)
	}
	createdAt := in.CreatedAt
	if createdAt.IsZero() {
		createdAt = time.Now().UTC()
	}

	const q = `
INSERT INTO notifications (id, user_id, category, payload, created_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, category, payload, read_at, created_at`
	return scanNotification(s.db.QueryRowContext(ctx, q, in.ID, in.UserID, in.Category, payload, createdAt))
}

func (s *PostgresStore) ListNotifications(ctx context.Context, in ListNotificationsInput) (ListNotificationsResult, error) {
	limit := NormalizeNotificationLimit(in.Limit)
	cursorTime, cursorID, err := ParseNotificationCursor(in.Cursor)
	if err != nil {
		return ListNotificationsResult{}, err
	}

	fetchLimit := limit + 1
	var rows *sql.Rows
	if cursorTime.IsZero() {
		const q = `
SELECT id, user_id, category, payload, read_at, created_at
FROM notifications
WHERE user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2`
		rows, err = s.db.QueryContext(ctx, q, in.UserID, fetchLimit)
	} else {
		const q = `
SELECT id, user_id, category, payload, read_at, created_at
FROM notifications
WHERE user_id = $1
  AND (created_at < $2 OR (created_at = $2 AND id < $3))
ORDER BY created_at DESC, id DESC
LIMIT $4`
		rows, err = s.db.QueryContext(ctx, q, in.UserID, cursorTime, cursorID, fetchLimit)
	}
	if err != nil {
		return ListNotificationsResult{}, err
	}
	defer rows.Close()

	var items []model.Notification
	for rows.Next() {
		n, err := scanNotification(rows)
		if err != nil {
			return ListNotificationsResult{}, err
		}
		items = append(items, *n)
	}
	if err := rows.Err(); err != nil {
		return ListNotificationsResult{}, err
	}

	result := ListNotificationsResult{}
	if len(items) > limit {
		result.Items = items[:limit]
		result.NextCursor = EncodeNotificationCursor(result.Items[len(result.Items)-1])
		return result, nil
	}
	result.Items = items
	return result, nil
}

func (s *PostgresStore) CountUnreadNotifications(ctx context.Context, userID string) (int64, error) {
	const q = `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL`
	var count int64
	err := s.db.QueryRowContext(ctx, q, userID).Scan(&count)
	return count, err
}

func (s *PostgresStore) MarkNotificationsRead(ctx context.Context, in MarkNotificationsReadInput) (int64, error) {
	readAt := in.ReadAt
	if readAt.IsZero() {
		readAt = time.Now().UTC()
	}

	if in.All || len(in.IDs) == 0 {
		const q = `
UPDATE notifications
SET read_at = $2
WHERE user_id = $1 AND read_at IS NULL`
		res, err := s.db.ExecContext(ctx, q, in.UserID, readAt)
		if err != nil {
			return 0, err
		}
		return res.RowsAffected()
	}

	ids := make([]string, 0, len(in.IDs))
	for _, id := range in.IDs {
		id = strings.TrimSpace(id)
		if id != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 {
		return 0, nil
	}

	const q = `
UPDATE notifications
SET read_at = $3
WHERE user_id = $1 AND read_at IS NULL AND id = ANY($2)`
	res, err := s.db.ExecContext(ctx, q, in.UserID, pq.Array(ids), readAt)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func (s *PostgresStore) ListSubscriptionRows(ctx context.Context, userID string) ([]model.NotificationSubscription, error) {
	const q = `SELECT category, enabled FROM notification_subscriptions WHERE user_id = $1 ORDER BY category`
	rows, err := s.db.QueryContext(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.NotificationSubscription
	for rows.Next() {
		var sub model.NotificationSubscription
		if err := rows.Scan(&sub.Category, &sub.Enabled); err != nil {
			return nil, err
		}
		out = append(out, sub)
	}
	return out, rows.Err()
}

func (s *PostgresStore) UpsertSubscriptions(ctx context.Context, userID string, updates []SubscriptionUpdate) error {
	for _, up := range updates {
		const q = `
INSERT INTO notification_subscriptions (user_id, category, enabled)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, category) DO UPDATE SET enabled = EXCLUDED.enabled`
		if _, err := s.db.ExecContext(ctx, q, userID, up.Category, up.Enabled); err != nil {
			return err
		}
	}
	return nil
}

func scanNotification(row rowScanner) (*model.Notification, error) {
	var n model.Notification
	var payload []byte
	var readAt sql.NullTime
	if err := row.Scan(&n.ID, &n.UserID, &n.Category, &payload, &readAt, &n.CreatedAt); err != nil {
		return nil, err
	}
	if len(payload) == 0 {
		n.Payload = json.RawMessage(`{}`)
	} else {
		n.Payload = json.RawMessage(payload)
	}
	if readAt.Valid {
		t := readAt.Time.UTC()
		n.ReadAt = &t
	}
	n.CreatedAt = n.CreatedAt.UTC()
	return &n, nil
}
