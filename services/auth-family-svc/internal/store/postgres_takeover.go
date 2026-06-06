package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) TransferAdmin(ctx context.Context, familyID, fromUserID, toUserID string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const checkFamily = `SELECT admin_user_id FROM families WHERE id = $1`
	var adminUserID string
	if err := tx.QueryRowContext(ctx, checkFamily, familyID).Scan(&adminUserID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if adminUserID != fromUserID {
		return fmt.Errorf("not admin")
	}

	const checkTarget = `
SELECT role FROM memberships
WHERE family_id = $1 AND user_id = $2 AND removed_at IS NULL`
	var targetRole string
	if err := tx.QueryRowContext(ctx, checkTarget, familyID, toUserID).Scan(&targetRole); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("invalid transfer target")
		}
		return err
	}
	if targetRole != string(model.MemberRoleFamily) {
		return fmt.Errorf("invalid transfer target")
	}

	const updateFamily = `UPDATE families SET admin_user_id = $2 WHERE id = $1 AND admin_user_id = $3`
	res, err := tx.ExecContext(ctx, updateFamily, familyID, toUserID, fromUserID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}

	const demote = `
UPDATE memberships SET role = 'family'
WHERE family_id = $1 AND user_id = $2 AND role = 'admin' AND removed_at IS NULL`
	if _, err := tx.ExecContext(ctx, demote, familyID, fromUserID); err != nil {
		return err
	}

	const promote = `
UPDATE memberships SET role = 'admin'
WHERE family_id = $1 AND user_id = $2 AND role = 'family' AND removed_at IS NULL`
	if _, err := tx.ExecContext(ctx, promote, familyID, toUserID); err != nil {
		return err
	}

	return tx.Commit()
}

func (s *PostgresStore) CreateTakeoverVote(ctx context.Context, vote model.TakeoverVote) (*model.TakeoverVote, error) {
	const activeQ = `
SELECT id FROM admin_takeover_votes
WHERE family_id = $1 AND status IN ('voting', 'objection_period')
LIMIT 1`
	var existingID string
	err := s.db.QueryRowContext(ctx, activeQ, vote.FamilyID).Scan(&existingID)
	if err == nil {
		return nil, ErrTakeoverInProgress
	}
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	const insertQ = `
INSERT INTO admin_takeover_votes (id, family_id, initiator_user_id, status, opens_at, created_at)
VALUES ($1, $2, $3, $4, $5, COALESCE($6, NOW()))
RETURNING id, family_id, initiator_user_id, status, opens_at, ends_at, completed_at, created_at`

	row := s.db.QueryRowContext(
		ctx,
		insertQ,
		vote.ID,
		vote.FamilyID,
		vote.InitiatorUserID,
		string(vote.Status),
		vote.OpensAt,
		nullTime(vote.CreatedAt),
	)
	return scanTakeoverVote(row)
}

func (s *PostgresStore) GetActiveTakeoverVote(ctx context.Context, familyID string) (*model.TakeoverVote, error) {
	const q = `
SELECT id, family_id, initiator_user_id, status, opens_at, ends_at, completed_at, created_at
FROM admin_takeover_votes
WHERE family_id = $1 AND status IN ('voting', 'objection_period')
ORDER BY created_at DESC
LIMIT 1`

	row := s.db.QueryRowContext(ctx, q, familyID)
	vote, err := scanTakeoverVote(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return vote, err
}

func (s *PostgresStore) CastTakeoverBallot(ctx context.Context, voteID, userID string, choice model.TakeoverBallotChoice, votedAt time.Time) error {
	const statusQ = `SELECT status FROM admin_takeover_votes WHERE id = $1`
	var status string
	if err := s.db.QueryRowContext(ctx, statusQ, voteID).Scan(&status); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if status != string(model.TakeoverStatusVoting) {
		return fmt.Errorf("vote not open")
	}

	const insertQ = `
INSERT INTO admin_takeover_ballots (vote_id, user_id, choice, voted_at)
VALUES ($1, $2, $3, $4)`
	_, err := s.db.ExecContext(ctx, insertQ, voteID, userID, string(choice), votedAt.UTC())
	if err != nil {
		if isUniqueViolation(err) {
			return ErrTakeoverAlreadyVoted
		}
		return err
	}
	return nil
}

func (s *PostgresStore) ListTakeoverBallots(ctx context.Context, voteID string) ([]model.TakeoverBallot, error) {
	const q = `
SELECT vote_id, user_id, choice, voted_at
FROM admin_takeover_ballots
WHERE vote_id = $1
ORDER BY voted_at ASC`

	rows, err := s.db.QueryContext(ctx, q, voteID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TakeoverBallot, 0)
	for rows.Next() {
		var ballot model.TakeoverBallot
		var choice string
		if err := rows.Scan(&ballot.VoteID, &ballot.UserID, &choice, &ballot.VotedAt); err != nil {
			return nil, err
		}
		ballot.Choice = model.TakeoverBallotChoice(choice)
		ballot.VotedAt = ballot.VotedAt.UTC()
		out = append(out, ballot)
	}
	return out, rows.Err()
}

func (s *PostgresStore) UpdateTakeoverVote(ctx context.Context, voteID string, status model.TakeoverVoteStatus, endsAt, completedAt *time.Time) error {
	const q = `
UPDATE admin_takeover_votes
SET status = $2,
    ends_at = COALESCE($3, ends_at),
    completed_at = COALESCE($4, completed_at)
WHERE id = $1`
	res, err := s.db.ExecContext(ctx, q, voteID, string(status), nullTimePtr(endsAt), nullTimePtr(completedAt))
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

func (s *PostgresStore) ListDueTakeoverVotes(ctx context.Context, before time.Time) ([]model.TakeoverVote, error) {
	const q = `
SELECT id, family_id, initiator_user_id, status, opens_at, ends_at, completed_at, created_at
FROM admin_takeover_votes
WHERE status = 'objection_period' AND ends_at IS NOT NULL AND ends_at <= $1
ORDER BY ends_at ASC`

	rows, err := s.db.QueryContext(ctx, q, before.UTC())
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.TakeoverVote, 0)
	for rows.Next() {
		vote, err := scanTakeoverVote(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *vote)
	}
	return out, rows.Err()
}

func (s *PostgresStore) CompleteTakeover(ctx context.Context, voteID, newAdminUserID string, completedAt time.Time) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	const voteQ = `
SELECT family_id, initiator_user_id, status
FROM admin_takeover_votes
WHERE id = $1 FOR UPDATE`
	var familyID, initiatorUserID, status string
	if err := tx.QueryRowContext(ctx, voteQ, voteID).Scan(&familyID, &initiatorUserID, &status); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if status != string(model.TakeoverStatusObjectionPeriod) {
		return fmt.Errorf("vote not in objection period")
	}
	if initiatorUserID != newAdminUserID {
		return fmt.Errorf("invalid transfer target")
	}

	const adminQ = `SELECT admin_user_id FROM families WHERE id = $1`
	var oldAdminID string
	if err := tx.QueryRowContext(ctx, adminQ, familyID).Scan(&oldAdminID); err != nil {
		return err
	}

	const updateFamily = `UPDATE families SET admin_user_id = $2 WHERE id = $1`
	if _, err := tx.ExecContext(ctx, updateFamily, familyID, newAdminUserID); err != nil {
		return err
	}
	const demote = `
UPDATE memberships SET role = 'family'
WHERE family_id = $1 AND user_id = $2 AND role = 'admin' AND removed_at IS NULL`
	if _, err := tx.ExecContext(ctx, demote, familyID, oldAdminID); err != nil {
		return err
	}
	const promote = `
UPDATE memberships SET role = 'admin'
WHERE family_id = $1 AND user_id = $2 AND role = 'family' AND removed_at IS NULL`
	if _, err := tx.ExecContext(ctx, promote, familyID, newAdminUserID); err != nil {
		return err
	}

	const completeVote = `
UPDATE admin_takeover_votes
SET status = 'completed', completed_at = $2
WHERE id = $1`
	if _, err := tx.ExecContext(ctx, completeVote, voteID, completedAt.UTC()); err != nil {
		return err
	}

	return tx.Commit()
}

func scanTakeoverVote(row rowScanner) (*model.TakeoverVote, error) {
	var vote model.TakeoverVote
	var status string
	var endsAt, completedAt sql.NullTime
	if err := row.Scan(
		&vote.ID,
		&vote.FamilyID,
		&vote.InitiatorUserID,
		&status,
		&vote.OpensAt,
		&endsAt,
		&completedAt,
		&vote.CreatedAt,
	); err != nil {
		return nil, err
	}
	vote.Status = model.TakeoverVoteStatus(status)
	vote.OpensAt = vote.OpensAt.UTC()
	vote.CreatedAt = vote.CreatedAt.UTC()
	if endsAt.Valid {
		t := endsAt.Time.UTC()
		vote.EndsAt = &t
	}
	if completedAt.Valid {
		t := completedAt.Time.UTC()
		vote.CompletedAt = &t
	}
	return &vote, nil
}

func nullTime(t time.Time) sql.NullTime {
	if t.IsZero() {
		return sql.NullTime{}
	}
	return sql.NullTime{Time: t.UTC(), Valid: true}
}

func nullTimePtr(t *time.Time) sql.NullTime {
	if t == nil {
		return sql.NullTime{}
	}
	return sql.NullTime{Time: t.UTC(), Valid: true}
}

func isUniqueViolation(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "duplicate key") || strings.Contains(msg, "unique constraint")
}
