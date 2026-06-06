package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) CountFamilyMembers(ctx context.Context, familyID string) (int, error) {
	const q = `SELECT COUNT(*) FROM memberships WHERE family_id = $1 AND removed_at IS NULL`
	var count int
	if err := s.db.QueryRowContext(ctx, q, familyID).Scan(&count); err != nil {
		return 0, fmt.Errorf("count family members: %w", err)
	}
	return count, nil
}

func (s *PostgresStore) CreateInviteCode(ctx context.Context, in CreateInviteCodeInput) (*model.InviteCode, error) {
	const q = `
INSERT INTO invite_codes (code, family_id, created_by, expire_at, max_uses, used_count, created_at)
VALUES ($1, $2, $3, $4, $5, 0, NOW())
RETURNING code, family_id, created_by, expire_at, max_uses, used_count, revoked_at, created_at`

	row := s.db.QueryRowContext(ctx, q, in.Code, in.FamilyID, in.CreatedBy, in.ExpireAt, in.MaxUses)
	return scanInviteCode(row)
}

func (s *PostgresStore) GetInviteCode(ctx context.Context, code string) (*model.InviteCode, error) {
	const q = `
SELECT code, family_id, created_by, expire_at, max_uses, used_count, revoked_at, created_at
FROM invite_codes
WHERE code = $1`

	row := s.db.QueryRowContext(ctx, q, code)
	invite, err := scanInviteCode(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return invite, err
}

func (s *PostgresStore) InviteCodeExists(ctx context.Context, code string) (bool, error) {
	const q = `SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = $1)`
	var exists bool
	if err := s.db.QueryRowContext(ctx, q, code).Scan(&exists); err != nil {
		return false, err
	}
	return exists, nil
}

func (s *PostgresStore) RevokeInviteCode(ctx context.Context, familyID, code string) error {
	const q = `
UPDATE invite_codes
SET revoked_at = NOW()
WHERE code = $1 AND family_id = $2 AND revoked_at IS NULL`
	res, err := s.db.ExecContext(ctx, q, code, familyID)
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

func (s *PostgresStore) JoinViaInvite(ctx context.Context, in JoinViaInviteInput) (*JoinViaInviteResult, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	const inviteQ = `
SELECT code, family_id, created_by, expire_at, max_uses, used_count, revoked_at, created_at
FROM invite_codes
WHERE code = $1
FOR UPDATE`

	row := tx.QueryRowContext(ctx, inviteQ, in.Code)
	invite, err := scanInviteCode(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if err := validateInviteForJoin(invite); err != nil {
		return nil, err
	}

	const memberCountQ = `SELECT COUNT(*) FROM memberships WHERE family_id = $1 AND removed_at IS NULL`
	var memberCount int
	if err := tx.QueryRowContext(ctx, memberCountQ, invite.FamilyID).Scan(&memberCount); err != nil {
		return nil, err
	}
	if memberCount >= 8 {
		return nil, ErrMemberLimit
	}

	const existingQ = `
SELECT EXISTS(
  SELECT 1 FROM memberships
  WHERE user_id = $1 AND family_id = $2 AND removed_at IS NULL
)`
	var alreadyMember bool
	if err := tx.QueryRowContext(ctx, existingQ, in.UserID, invite.FamilyID).Scan(&alreadyMember); err != nil {
		return nil, err
	}
	if alreadyMember {
		return nil, ErrAlreadyMember
	}

	joinedAt := time.Now().UTC()
	const insertMembership = `
INSERT INTO memberships (user_id, family_id, role, nickname, joined_at)
VALUES ($1, $2, 'family', $3, $4)`
	if _, err := tx.ExecContext(ctx, insertMembership, in.UserID, invite.FamilyID, in.Nickname, joinedAt); err != nil {
		return nil, err
	}

	const updateInvite = `
UPDATE invite_codes
SET used_count = used_count + 1
WHERE code = $1`
	if _, err := tx.ExecContext(ctx, updateInvite, in.Code); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &JoinViaInviteResult{
		FamilyID: invite.FamilyID,
		Role:     model.MemberRoleFamily,
		JoinedAt: joinedAt,
	}, nil
}

func validateInviteForJoin(invite *model.InviteCode) error {
	now := time.Now().UTC()
	if invite.RevokedAt != nil {
		return ErrInviteExpired
	}
	if !invite.ExpireAt.After(now) {
		return ErrInviteExpired
	}
	if invite.UsedCount >= invite.MaxUses {
		return ErrInviteUsedUp
	}
	return nil
}

func scanInviteCode(row rowScanner) (*model.InviteCode, error) {
	var (
		invite    model.InviteCode
		revokedAt sql.NullTime
	)
	if err := row.Scan(
		&invite.Code,
		&invite.FamilyID,
		&invite.CreatedBy,
		&invite.ExpireAt,
		&invite.MaxUses,
		&invite.UsedCount,
		&revokedAt,
		&invite.CreatedAt,
	); err != nil {
		return nil, err
	}
	invite.ExpireAt = invite.ExpireAt.UTC()
	invite.CreatedAt = invite.CreatedAt.UTC()
	if revokedAt.Valid {
		t := revokedAt.Time.UTC()
		invite.RevokedAt = &t
	}
	return &invite, nil
}
