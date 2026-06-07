package store

import "errors"

var (
	// ErrNotFound is returned when a record does not exist.
	ErrNotFound = errors.New("not found")
	// ErrDuplicateLike is returned when a like already exists for post_id+user_id.
	ErrDuplicateLike = errors.New("duplicate like")
)
