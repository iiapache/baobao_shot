package store

import (
	"context"
	"fmt"
)

func (s *PostgresStore) ListFamilyPosts(ctx context.Context, in ListFamilyPostsInput) (ListFamilyPostsResult, error) {
	limit := NormalizeFeedLimit(in.Limit)
	cursorTime, cursorID, err := ParseFeedCursor(in.Cursor)
	if err != nil {
		return ListFamilyPostsResult{}, err
	}

	args := []any{in.FamilyID}
	q := `
SELECT id, family_id, owner_user_id, baby_ids, caption, visibility, status, created_at, audited_at, deleted_at
FROM posts
WHERE family_id = $1
  AND deleted_at IS NULL
  AND visibility = 'family'
  AND status IN ('published', 'audit')`

	if !cursorTime.IsZero() {
		args = append(args, cursorTime, cursorID)
		n := len(args)
		q += fmt.Sprintf(`
  AND (created_at < $%d OR (created_at = $%d AND id < $%d))`, n-1, n-1, n)
	}

	args = append(args, limit+1)
	q += fmt.Sprintf(`
ORDER BY created_at DESC, id DESC
LIMIT $%d`, len(args))

	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return ListFamilyPostsResult{}, err
	}
	defer rows.Close()

	result := ListFamilyPostsResult{}
	for rows.Next() {
		post, err := scanPost(rows)
		if err != nil {
			return ListFamilyPostsResult{}, err
		}
		result.Posts = append(result.Posts, *post)
	}
	if err := rows.Err(); err != nil {
		return ListFamilyPostsResult{}, err
	}

	if len(result.Posts) > limit {
		result.NextCursor = EncodeFeedCursor(result.Posts[limit-1])
		result.Posts = result.Posts[:limit]
	}
	return result, nil
}
