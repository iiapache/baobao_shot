package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

func (s *MemoryStore) CreateBaby(_ context.Context, in CreateBabyInput) (*model.Baby, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.families[in.FamilyID]; !ok {
		return nil, ErrNotFound
	}
	now := time.Now().UTC()
	baby := &model.Baby{
		ID:          in.ID,
		FamilyID:    in.FamilyID,
		Name:        in.Name,
		FullName:    in.FullName,
		Gender:      in.Gender,
		BirthDate:   dateOnlyUTC(in.BirthDate),
		BirthTime:   cloneTimePtr(in.BirthTime),
		BirthWeight: in.BirthWeight,
		BirthLength: in.BirthLength,
		BirthPlace:  in.BirthPlace,
		Timezone:    in.Timezone,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	s.babies[in.ID] = baby
	return cloneBaby(baby), nil
}

func (s *MemoryStore) ListBabiesByFamily(_ context.Context, familyID string) ([]model.Baby, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]model.Baby, 0)
	for _, baby := range s.babies {
		if baby.FamilyID == familyID && baby.DeletedAt == nil {
			out = append(out, *cloneBaby(baby))
		}
	}
	return out, nil
}

func (s *MemoryStore) GetBaby(_ context.Context, babyID string) (*model.Baby, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	baby, ok := s.babies[babyID]
	if !ok || baby.DeletedAt != nil {
		return nil, ErrNotFound
	}
	return cloneBaby(baby), nil
}

func (s *MemoryStore) UpdateBaby(_ context.Context, babyID string, in UpdateBabyInput) (*model.Baby, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	baby, ok := s.babies[babyID]
	if !ok || baby.DeletedAt != nil {
		return nil, ErrNotFound
	}
	if in.Name != nil {
		baby.Name = *in.Name
	}
	if in.FullName != nil {
		baby.FullName = in.FullName
	}
	if in.Gender != nil {
		baby.Gender = *in.Gender
	}
	if in.BirthDate != nil {
		baby.BirthDate = dateOnlyUTC(*in.BirthDate)
	}
	if in.BirthTime != nil {
		baby.BirthTime = cloneTimePtr(in.BirthTime)
	}
	if in.BirthWeight != nil {
		baby.BirthWeight = in.BirthWeight
	}
	if in.BirthLength != nil {
		baby.BirthLength = in.BirthLength
	}
	if in.BirthPlace != nil {
		baby.BirthPlace = in.BirthPlace
	}
	if in.Timezone != nil {
		baby.Timezone = *in.Timezone
	}
	if in.AvatarURL != nil {
		baby.AvatarURL = in.AvatarURL
	}
	baby.UpdatedAt = time.Now().UTC()
	return cloneBaby(baby), nil
}

func (s *MemoryStore) SoftDeleteBaby(_ context.Context, babyID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	baby, ok := s.babies[babyID]
	if !ok || baby.DeletedAt != nil {
		return ErrNotFound
	}
	now := time.Now().UTC()
	baby.DeletedAt = &now
	baby.UpdatedAt = now
	return nil
}

func cloneBaby(b *model.Baby) *model.Baby {
	if b == nil {
		return nil
	}
	copy := *b
	copy.BirthDate = dateOnlyUTC(b.BirthDate)
	copy.BirthTime = cloneTimePtr(b.BirthTime)
	if b.FullName != nil {
		v := *b.FullName
		copy.FullName = &v
	}
	if b.BirthPlace != nil {
		v := *b.BirthPlace
		copy.BirthPlace = &v
	}
	if b.AvatarURL != nil {
		v := *b.AvatarURL
		copy.AvatarURL = &v
	}
	if b.BirthWeight != nil {
		v := *b.BirthWeight
		copy.BirthWeight = &v
	}
	if b.BirthLength != nil {
		v := *b.BirthLength
		copy.BirthLength = &v
	}
	if b.DeletedAt != nil {
		t := b.DeletedAt.UTC()
		copy.DeletedAt = &t
	}
	copy.CreatedAt = b.CreatedAt.UTC()
	copy.UpdatedAt = b.UpdatedAt.UTC()
	return &copy
}

func dateOnlyUTC(t time.Time) time.Time {
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func cloneTimePtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	v := *t
	return &v
}

func (s *PostgresStore) CreateBaby(ctx context.Context, in CreateBabyInput) (*model.Baby, error) {
	const q = `
INSERT INTO babies (
    id, family_id, name, full_name, gender, birth_date, birth_time,
    birth_weight, birth_length, birth_place, timezone, created_at, updated_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW())
RETURNING id, family_id, name, full_name, gender, birth_date, birth_time,
          birth_weight, birth_length, birth_place, timezone, avatar_url,
          created_at, updated_at, deleted_at`

	row := s.db.QueryRowContext(ctx, q,
		in.ID, in.FamilyID, in.Name, nullString(in.FullName), string(in.Gender),
		dateOnlyUTC(in.BirthDate), nullTimeOfDay(in.BirthTime),
		nullFloat(in.BirthWeight), nullFloat(in.BirthLength), nullString(in.BirthPlace), in.Timezone,
	)
	return scanBaby(row)
}

func (s *PostgresStore) ListBabiesByFamily(ctx context.Context, familyID string) ([]model.Baby, error) {
	const q = `
SELECT id, family_id, name, full_name, gender, birth_date, birth_time,
       birth_weight, birth_length, birth_place, timezone, avatar_url,
       created_at, updated_at, deleted_at
FROM babies
WHERE family_id = $1 AND deleted_at IS NULL
ORDER BY created_at ASC`

	rows, err := s.db.QueryContext(ctx, q, familyID)
	if err != nil {
		return nil, fmt.Errorf("list babies: %w", err)
	}
	defer rows.Close()

	out := make([]model.Baby, 0)
	for rows.Next() {
		baby, err := scanBaby(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *baby)
	}
	return out, rows.Err()
}

func (s *PostgresStore) GetBaby(ctx context.Context, babyID string) (*model.Baby, error) {
	const q = `
SELECT id, family_id, name, full_name, gender, birth_date, birth_time,
       birth_weight, birth_length, birth_place, timezone, avatar_url,
       created_at, updated_at, deleted_at
FROM babies
WHERE id = $1 AND deleted_at IS NULL`

	row := s.db.QueryRowContext(ctx, q, babyID)
	baby, err := scanBaby(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return baby, err
}

func (s *PostgresStore) UpdateBaby(ctx context.Context, babyID string, in UpdateBabyInput) (*model.Baby, error) {
	current, err := s.GetBaby(ctx, babyID)
	if err != nil {
		return nil, err
	}

	name := current.Name
	if in.Name != nil {
		name = *in.Name
	}
	gender := string(current.Gender)
	if in.Gender != nil {
		gender = string(*in.Gender)
	}
	birthDate := current.BirthDate
	if in.BirthDate != nil {
		birthDate = dateOnlyUTC(*in.BirthDate)
	}
	birthTime := current.BirthTime
	if in.BirthTime != nil {
		birthTime = in.BirthTime
	}
	fullName := current.FullName
	if in.FullName != nil {
		fullName = in.FullName
	}
	birthWeight := current.BirthWeight
	if in.BirthWeight != nil {
		birthWeight = in.BirthWeight
	}
	birthLength := current.BirthLength
	if in.BirthLength != nil {
		birthLength = in.BirthLength
	}
	birthPlace := current.BirthPlace
	if in.BirthPlace != nil {
		birthPlace = in.BirthPlace
	}
	timezone := current.Timezone
	if in.Timezone != nil {
		timezone = *in.Timezone
	}
	avatarURL := current.AvatarURL
	if in.AvatarURL != nil {
		avatarURL = in.AvatarURL
	}

	const q = `
UPDATE babies
SET name = $2, full_name = $3, gender = $4, birth_date = $5, birth_time = $6,
    birth_weight = $7, birth_length = $8, birth_place = $9, timezone = $10,
    avatar_url = $11, updated_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, family_id, name, full_name, gender, birth_date, birth_time,
          birth_weight, birth_length, birth_place, timezone, avatar_url,
          created_at, updated_at, deleted_at`

	row := s.db.QueryRowContext(ctx, q, babyID, name, nullString(fullName), gender, birthDate,
		nullTimeOfDay(birthTime), nullFloat(birthWeight), nullFloat(birthLength),
		nullString(birthPlace), timezone, nullString(avatarURL))
	baby, err := scanBaby(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return baby, err
}

func (s *PostgresStore) SoftDeleteBaby(ctx context.Context, babyID string) error {
	const q = `UPDATE babies SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL`
	res, err := s.db.ExecContext(ctx, q, babyID)
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

func scanBaby(row rowScanner) (*model.Baby, error) {
	var (
		baby        model.Baby
		fullName    sql.NullString
		birthTime   sql.NullString
		birthWeight sql.NullFloat64
		birthLength sql.NullFloat64
		birthPlace  sql.NullString
		avatarURL   sql.NullString
		deletedAt   sql.NullTime
		gender      string
	)

	if err := row.Scan(
		&baby.ID, &baby.FamilyID, &baby.Name, &fullName, &gender, &baby.BirthDate,
		&birthTime, &birthWeight, &birthLength, &birthPlace, &baby.Timezone, &avatarURL,
		&baby.CreatedAt, &baby.UpdatedAt, &deletedAt,
	); err != nil {
		return nil, err
	}

	baby.Gender = model.BabyGender(gender)
	baby.BirthDate = dateOnlyUTC(baby.BirthDate)
	if fullName.Valid {
		baby.FullName = &fullName.String
	}
	if birthTime.Valid {
		if t, err := time.Parse("15:04:05", birthTime.String); err == nil {
			baby.BirthTime = &t
		}
	}
	if birthWeight.Valid {
		v := birthWeight.Float64
		baby.BirthWeight = &v
	}
	if birthLength.Valid {
		v := birthLength.Float64
		baby.BirthLength = &v
	}
	if birthPlace.Valid {
		baby.BirthPlace = &birthPlace.String
	}
	if avatarURL.Valid {
		baby.AvatarURL = &avatarURL.String
	}
	if deletedAt.Valid {
		t := deletedAt.Time.UTC()
		baby.DeletedAt = &t
	}
	baby.CreatedAt = baby.CreatedAt.UTC()
	baby.UpdatedAt = baby.UpdatedAt.UTC()
	return &baby, nil
}

func nullString(v *string) sql.NullString {
	if v == nil {
		return sql.NullString{}
	}
	return sql.NullString{String: *v, Valid: true}
}

func nullFloat(v *float64) sql.NullFloat64 {
	if v == nil {
		return sql.NullFloat64{}
	}
	return sql.NullFloat64{Float64: *v, Valid: true}
}

func nullTimeOfDay(t *time.Time) sql.NullString {
	if t == nil {
		return sql.NullString{}
	}
	return sql.NullString{String: t.Format("15:04:05"), Valid: true}
}
