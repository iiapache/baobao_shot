package store

import (
	"context"
	"database/sql"

	"github.com/baobao/notification-svc/internal/model"
)

func (s *PostgresStore) UpsertDeviceToken(ctx context.Context, in UpsertDeviceTokenInput) (*model.DeviceToken, error) {
	const q = `
INSERT INTO device_tokens (user_id, device_id, apns_token, region, app_version, os_version, model, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (user_id, device_id) DO UPDATE SET
    apns_token = EXCLUDED.apns_token,
    region = EXCLUDED.region,
    app_version = EXCLUDED.app_version,
    os_version = EXCLUDED.os_version,
    model = EXCLUDED.model,
    updated_at = EXCLUDED.updated_at
RETURNING user_id, device_id, apns_token, region, app_version, os_version, model, updated_at`
	return scanDeviceToken(s.db.QueryRowContext(ctx, q,
		in.UserID, in.DeviceID, in.APNSToken, in.Region, in.AppVersion, in.OSVersion, in.Model, in.UpdatedAt,
	))
}

func (s *PostgresStore) DeleteDeviceToken(ctx context.Context, userID, deviceID string) error {
	const q = `DELETE FROM device_tokens WHERE user_id = $1 AND device_id = $2`
	res, err := s.db.ExecContext(ctx, q, userID, deviceID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteByAPNSToken(ctx context.Context, apnsToken string) (int64, error) {
	const q = `DELETE FROM device_tokens WHERE apns_token = $1`
	res, err := s.db.ExecContext(ctx, q, apnsToken)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func (s *PostgresStore) ListDeviceTokensByUser(ctx context.Context, userID string) ([]model.DeviceToken, error) {
	const q = `
SELECT user_id, device_id, apns_token, region, app_version, os_version, model, updated_at
FROM device_tokens
WHERE user_id = $1
ORDER BY updated_at DESC`
	rows, err := s.db.QueryContext(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.DeviceToken
	for rows.Next() {
		dt, err := scanDeviceToken(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *dt)
	}
	return out, rows.Err()
}

func (s *PostgresStore) GetDeviceToken(ctx context.Context, userID, deviceID string) (*model.DeviceToken, error) {
	const q = `
SELECT user_id, device_id, apns_token, region, app_version, os_version, model, updated_at
FROM device_tokens
WHERE user_id = $1 AND device_id = $2`
	dt, err := scanDeviceToken(s.db.QueryRowContext(ctx, q, userID, deviceID))
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	return dt, err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanDeviceToken(row rowScanner) (*model.DeviceToken, error) {
	var dt model.DeviceToken
	if err := row.Scan(
		&dt.UserID, &dt.DeviceID, &dt.APNSToken, &dt.Region,
		&dt.AppVersion, &dt.OSVersion, &dt.Model, &dt.UpdatedAt,
	); err != nil {
		return nil, err
	}
	return &dt, nil
}
