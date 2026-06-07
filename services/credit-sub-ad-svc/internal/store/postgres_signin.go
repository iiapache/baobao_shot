package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

func (s *PostgresStore) GetSignIn(ctx context.Context, userID string, date time.Time) (*model.SignInRecord, error) {
	const q = `
SELECT user_id, date, credits_granted, streak
FROM sign_ins
WHERE user_id = $1 AND date = $2::date`
	day := utcDate(date)
	row := s.db.QueryRowContext(ctx, q, userID, day)
	rec, err := scanSignInRecord(row)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get sign-in: %w", err)
	}
	return rec, nil
}

func (s *PostgresStore) RecordSignIn(ctx context.Context, rec model.SignInRecord) (bool, error) {
	const q = `
INSERT INTO sign_ins (user_id, date, credits_granted, streak)
VALUES ($1, $2::date, $3, $4)
ON CONFLICT (user_id, date) DO NOTHING
RETURNING user_id`
	day := utcDate(rec.Date)
	var insertedUserID string
	err := s.db.QueryRowContext(ctx, q, rec.UserID, day, rec.CreditsGranted, rec.Streak).Scan(&insertedUserID)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("record sign-in: %w", err)
	}
	return true, nil
}

func scanSignInRecord(row interface {
	Scan(dest ...any) error
}) (*model.SignInRecord, error) {
	var rec model.SignInRecord
	var day time.Time
	if err := row.Scan(&rec.UserID, &day, &rec.CreditsGranted, &rec.Streak); err != nil {
		return nil, err
	}
	rec.Date = utcDate(day)
	return &rec, nil
}

func utcDate(t time.Time) time.Time {
	utc := t.UTC()
	return time.Date(utc.Year(), utc.Month(), utc.Day(), 0, 0, 0, 0, time.UTC)
}
