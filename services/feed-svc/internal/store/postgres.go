package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/baobao/feed-svc/internal/model"
	"github.com/lib/pq"
)

// PostgresStore implements Store backed by PostgreSQL.
type PostgresStore struct {
	db *sql.DB
}

// NewPostgresStore wraps an existing *sql.DB connection pool.
func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.db.PingContext(ctx)
}

func (s *PostgresStore) CreatePost(ctx context.Context, in CreatePostInput) (*model.Post, error) {
	babyIDs, err := encodeJSONStringSlice(in.BabyIDs)
	if err != nil {
		return nil, err
	}
	const q = `
INSERT INTO posts (id, family_id, owner_user_id, baby_ids, caption, visibility, status, created_at)
VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, $8)
RETURNING id, family_id, owner_user_id, baby_ids, caption, visibility, status, created_at, audited_at, deleted_at`
	return scanPost(s.db.QueryRowContext(ctx, q,
		in.ID, in.FamilyID, in.OwnerUserID, string(babyIDs), in.Caption, in.Visibility, in.Status, in.CreatedAt,
	))
}

func (s *PostgresStore) UpdatePostStatus(ctx context.Context, postID, status string, auditedAt *time.Time) error {
	const q = `
UPDATE posts
SET status = $2, audited_at = $3
WHERE id = $1 AND deleted_at IS NULL`
	res, err := s.db.ExecContext(ctx, q, postID, status, auditedAt)
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

func (s *PostgresStore) GetPost(ctx context.Context, postID string) (*model.Post, error) {
	const q = `
SELECT id, family_id, owner_user_id, baby_ids, caption, visibility, status, created_at, audited_at, deleted_at
FROM posts
WHERE id = $1 AND deleted_at IS NULL`
	post, err := scanPost(s.db.QueryRowContext(ctx, q, postID))
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	return post, err
}

func (s *PostgresStore) SoftDeletePost(ctx context.Context, postID string, deletedAt time.Time) error {
	const q = `
UPDATE posts
SET deleted_at = $2, status = $3
WHERE id = $1 AND deleted_at IS NULL`
	res, err := s.db.ExecContext(ctx, q, postID, deletedAt, model.PostStatusRemoved)
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

func (s *PostgresStore) SoftDeletePostItemsByPostID(ctx context.Context, postID string, deletedAt time.Time) error {
	const q = `
UPDATE post_items
SET deleted_at = $2
WHERE post_id = $1 AND deleted_at IS NULL`
	_, err := s.db.ExecContext(ctx, q, postID, deletedAt)
	return err
}

func (s *PostgresStore) CreatePostItem(ctx context.Context, in CreatePostItemInput) (*model.PostItem, error) {
	const q = `
INSERT INTO post_items (id, post_id, kind, object_key, mime, width, height, duration, deep_synth, thumbnail_key)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING id, post_id, kind, object_key, mime, width, height, duration, deep_synth, thumbnail_key, deleted_at`
	return scanPostItem(s.db.QueryRowContext(ctx, q,
		in.ID, in.PostID, in.Kind, in.ObjectKey, in.Mime, in.Width, in.Height, in.Duration, in.DeepSynth, in.ThumbnailKey,
	))
}

func (s *PostgresStore) ListPostItems(ctx context.Context, postID string) ([]model.PostItem, error) {
	const q = `
SELECT id, post_id, kind, object_key, mime, width, height, duration, deep_synth, thumbnail_key, deleted_at
FROM post_items
WHERE post_id = $1 AND deleted_at IS NULL
ORDER BY id`
	rows, err := s.db.QueryContext(ctx, q, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.PostItem
	for rows.Next() {
		item, err := scanPostItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}

func (s *PostgresStore) CreateComment(ctx context.Context, in CreateCommentInput) (*model.Comment, error) {
	const q = `
INSERT INTO comments (id, post_id, user_id, parent_id, text, status, created_at)
SELECT $1, $2, $3, $4, $5, $6, $7
WHERE EXISTS (
	SELECT 1 FROM posts WHERE id = $2 AND deleted_at IS NULL
)
RETURNING id, post_id, user_id, parent_id, text, status, created_at, deleted_at`
	comment, err := scanComment(s.db.QueryRowContext(ctx, q,
		in.ID, in.PostID, in.UserID, in.ParentID, in.Text, in.Status, in.CreatedAt,
	))
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	return comment, err
}

func (s *PostgresStore) GetComment(ctx context.Context, commentID string) (*model.Comment, error) {
	const q = `
SELECT id, post_id, user_id, parent_id, text, status, created_at, deleted_at
FROM comments
WHERE id = $1 AND deleted_at IS NULL`
	comment, err := scanComment(s.db.QueryRowContext(ctx, q, commentID))
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	return comment, err
}

func (s *PostgresStore) SoftDeleteComment(ctx context.Context, commentID string, deletedAt time.Time) error {
	const q = `
UPDATE comments
SET deleted_at = $2, status = $3
WHERE id = $1 AND deleted_at IS NULL`
	res, err := s.db.ExecContext(ctx, q, commentID, deletedAt, model.CommentStatusRemoved)
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

func (s *PostgresStore) AddLike(ctx context.Context, postID, userID string, likedAt time.Time) error {
	const q = `INSERT INTO likes (post_id, user_id, liked_at) VALUES ($1, $2, $3)`
	_, err := s.db.ExecContext(ctx, q, postID, userID, likedAt)
	if err == nil {
		return nil
	}
	if pqErr, ok := err.(*pq.Error); ok && pqErr.Code == "23505" {
		return ErrDuplicateLike
	}
	return err
}

func (s *PostgresStore) RemoveLike(ctx context.Context, postID, userID string) error {
	const q = `DELETE FROM likes WHERE post_id = $1 AND user_id = $2`
	res, err := s.db.ExecContext(ctx, q, postID, userID)
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

func (s *PostgresStore) CreateAuditLog(ctx context.Context, in CreateAuditLogInput) (*model.FeedAuditLog, error) {
	reasons, err := encodeJSONStringSlice(in.Reasons)
	if err != nil {
		return nil, err
	}
	const q = `
INSERT INTO feed_audit_logs (id, target_kind, target_id, result, reasons, reviewer, created_at)
VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)
RETURNING id, target_kind, target_id, result, reasons, reviewer, created_at`
	return scanAuditLog(s.db.QueryRowContext(ctx, q,
		in.ID, in.TargetKind, in.TargetID, in.Result, string(reasons), in.Reviewer, in.CreatedAt,
	))
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPost(row rowScanner) (*model.Post, error) {
	var post model.Post
	var babyIDsJSON []byte
	var auditedAt, deletedAt sql.NullTime
	if err := row.Scan(
		&post.ID, &post.FamilyID, &post.OwnerUserID, &babyIDsJSON, &post.Caption,
		&post.Visibility, &post.Status, &post.CreatedAt, &auditedAt, &deletedAt,
	); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(babyIDsJSON, &post.BabyIDs); err != nil {
		return nil, fmt.Errorf("decode baby_ids: %w", err)
	}
	if auditedAt.Valid {
		t := auditedAt.Time
		post.AuditedAt = &t
	}
	if deletedAt.Valid {
		t := deletedAt.Time
		post.DeletedAt = &t
	}
	return &post, nil
}

func scanPostItem(row rowScanner) (*model.PostItem, error) {
	var item model.PostItem
	var duration sql.NullInt64
	var thumbnailKey sql.NullString
	var deletedAt sql.NullTime
	if err := row.Scan(
		&item.ID, &item.PostID, &item.Kind, &item.ObjectKey, &item.Mime,
		&item.Width, &item.Height, &duration, &item.DeepSynth, &thumbnailKey, &deletedAt,
	); err != nil {
		return nil, err
	}
	if duration.Valid {
		v := int(duration.Int64)
		item.Duration = &v
	}
	if thumbnailKey.Valid {
		v := thumbnailKey.String
		item.ThumbnailKey = &v
	}
	if deletedAt.Valid {
		t := deletedAt.Time
		item.DeletedAt = &t
	}
	return &item, nil
}

func scanComment(row rowScanner) (*model.Comment, error) {
	var c model.Comment
	var parentID sql.NullString
	var deletedAt sql.NullTime
	if err := row.Scan(
		&c.ID, &c.PostID, &c.UserID, &parentID, &c.Text, &c.Status, &c.CreatedAt, &deletedAt,
	); err != nil {
		return nil, err
	}
	if parentID.Valid {
		v := parentID.String
		c.ParentID = &v
	}
	if deletedAt.Valid {
		t := deletedAt.Time
		c.DeletedAt = &t
	}
	return &c, nil
}

func scanAuditLog(row rowScanner) (*model.FeedAuditLog, error) {
	var log model.FeedAuditLog
	var reasonsJSON []byte
	if err := row.Scan(
		&log.ID, &log.TargetKind, &log.TargetID, &log.Result, &reasonsJSON, &log.Reviewer, &log.CreatedAt,
	); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(reasonsJSON, &log.Reasons); err != nil {
		return nil, fmt.Errorf("decode reasons: %w", err)
	}
	return &log, nil
}

// ApplyMigrations runs embedded SQL migrations.
func ApplyMigrations(ctx context.Context, db *sql.DB, sql string) error {
	if _, err := db.ExecContext(ctx, sql); err != nil {
		return fmt.Errorf("apply migration: %w", err)
	}
	return nil
}

// WaitForPostgres pings until the database is reachable or timeout elapses.
func WaitForPostgres(ctx context.Context, db *sql.DB) error {
	deadline, ok := ctx.Deadline()
	if !ok {
		deadline = time.Now().Add(10 * time.Second)
	}
	for time.Now().Before(deadline) {
		if err := db.PingContext(ctx); err == nil {
			return nil
		}
		time.Sleep(200 * time.Millisecond)
	}
	return db.PingContext(ctx)
}
