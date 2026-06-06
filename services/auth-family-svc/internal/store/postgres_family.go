package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *PostgresStore) CountCreatedFamilies(ctx context.Context, userID string) (int, error) {
	const q = `SELECT COUNT(*) FROM families WHERE admin_user_id = $1`
	var count int
	if err := s.db.QueryRowContext(ctx, q, userID).Scan(&count); err != nil {
		return 0, fmt.Errorf("count created families: %w", err)
	}
	return count, nil
}

func (s *PostgresStore) CountActiveMemberships(ctx context.Context, userID string) (int, error) {
	const q = `SELECT COUNT(*) FROM memberships WHERE user_id = $1 AND removed_at IS NULL`
	var count int
	if err := s.db.QueryRowContext(ctx, q, userID).Scan(&count); err != nil {
		return 0, fmt.Errorf("count memberships: %w", err)
	}
	return count, nil
}

func (s *PostgresStore) CreateFamily(ctx context.Context, in CreateFamilyInput) (*model.Family, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	const insertFamily = `
INSERT INTO families (id, name, admin_user_id, region, plan, created_at)
VALUES ($1, $2, $3, $4, 'free', NOW())
RETURNING id, name, admin_user_id, region, plan, created_at`

	row := tx.QueryRowContext(ctx, insertFamily, in.ID, in.Name, in.AdminUserID, in.Region)
	family, err := scanFamily(row)
	if err != nil {
		return nil, fmt.Errorf("insert family: %w", err)
	}

	const insertMembership = `
INSERT INTO memberships (user_id, family_id, role, nickname, joined_at)
VALUES ($1, $2, 'admin', '', NOW())`
	if _, err := tx.ExecContext(ctx, insertMembership, in.AdminUserID, in.ID); err != nil {
		return nil, fmt.Errorf("insert admin membership: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return family, nil
}

func (s *PostgresStore) ListUserFamilies(ctx context.Context, userID string) ([]FamilySummary, error) {
	const q = `
SELECT f.id, f.name, f.admin_user_id, f.region, f.plan, f.created_at, m.role
FROM memberships m
JOIN families f ON f.id = m.family_id
WHERE m.user_id = $1 AND m.removed_at IS NULL
ORDER BY f.created_at ASC`

	rows, err := s.db.QueryContext(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("list families: %w", err)
	}
	defer rows.Close()

	out := make([]FamilySummary, 0)
	for rows.Next() {
		var (
			family model.Family
			role   string
		)
		if err := rows.Scan(
			&family.ID, &family.Name, &family.AdminUserID, &family.Region, &family.Plan, &family.CreatedAt, &role,
		); err != nil {
			return nil, err
		}
		family.CreatedAt = family.CreatedAt.UTC()
		out = append(out, FamilySummary{Family: family, Role: model.MemberRole(role)})
	}
	return out, rows.Err()
}

func (s *PostgresStore) GetFamilyDetail(ctx context.Context, familyID, userID string) (*FamilyDetail, error) {
	const familyQ = `
SELECT f.id, f.name, f.admin_user_id, f.region, f.plan, f.created_at, m.role
FROM families f
JOIN memberships m ON m.family_id = f.id AND m.user_id = $2 AND m.removed_at IS NULL
WHERE f.id = $1`

	row := s.db.QueryRowContext(ctx, familyQ, familyID, userID)
	var (
		family model.Family
		role   string
	)
	if err := row.Scan(
		&family.ID, &family.Name, &family.AdminUserID, &family.Region, &family.Plan, &family.CreatedAt, &role,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	family.CreatedAt = family.CreatedAt.UTC()

	members, err := s.listFamilyMembers(ctx, familyID)
	if err != nil {
		return nil, err
	}

	return &FamilyDetail{
		Family:  family,
		Role:    model.MemberRole(role),
		Members: members,
	}, nil
}

func (s *PostgresStore) UpdateFamilyName(ctx context.Context, familyID, userID, name string) (*model.Family, error) {
	const q = `
UPDATE families f
SET name = $3
FROM memberships m
WHERE f.id = $1 AND m.family_id = f.id AND m.user_id = $2 AND m.removed_at IS NULL
RETURNING f.id, f.name, f.admin_user_id, f.region, f.plan, f.created_at`

	row := s.db.QueryRowContext(ctx, q, familyID, userID, name)
	family, err := scanFamily(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return family, err
}

func (s *PostgresStore) DeleteFamily(ctx context.Context, familyID, userID string) error {
	const q = `DELETE FROM families WHERE id = $1 AND admin_user_id = $2`
	res, err := s.db.ExecContext(ctx, q, familyID, userID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		var exists bool
		checkQ := `SELECT EXISTS(SELECT 1 FROM families WHERE id = $1)`
		if err := s.db.QueryRowContext(ctx, checkQ, familyID).Scan(&exists); err != nil {
			return err
		}
		if !exists {
			return ErrNotFound
		}
		return fmt.Errorf("not admin")
	}
	return nil
}

func (s *PostgresStore) AddMembership(ctx context.Context, m model.Membership) error {
	const q = `
INSERT INTO memberships (user_id, family_id, role, nickname, joined_at)
VALUES ($1, $2, $3, $4, COALESCE($5, NOW()))`
	joinedAt := sql.NullTime{}
	if !m.JoinedAt.IsZero() {
		joinedAt = sql.NullTime{Time: m.JoinedAt, Valid: true}
	}
	_, err := s.db.ExecContext(ctx, q, m.UserID, m.FamilyID, string(m.Role), m.Nickname, joinedAt)
	return err
}

func (s *PostgresStore) listFamilyMembers(ctx context.Context, familyID string) ([]model.FamilyMember, error) {
	const q = `
SELECT user_id, role, nickname, joined_at
FROM memberships
WHERE family_id = $1 AND removed_at IS NULL
ORDER BY joined_at ASC`

	rows, err := s.db.QueryContext(ctx, q, familyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]model.FamilyMember, 0)
	for rows.Next() {
		var (
			member model.FamilyMember
			role   string
		)
		if err := rows.Scan(&member.UserID, &role, &member.Nickname, &member.JoinedAt); err != nil {
			return nil, err
		}
		member.Role = model.MemberRole(role)
		member.JoinedAt = member.JoinedAt.UTC()
		out = append(out, member)
	}
	return out, rows.Err()
}

func scanFamily(row rowScanner) (*model.Family, error) {
	var family model.Family
	if err := row.Scan(&family.ID, &family.Name, &family.AdminUserID, &family.Region, &family.Plan, &family.CreatedAt); err != nil {
		return nil, err
	}
	family.CreatedAt = family.CreatedAt.UTC()
	return &family, nil
}
