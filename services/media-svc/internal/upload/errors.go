package upload

import "errors"

var (
	ErrUnauthorized     = errors.New("unauthorized")
	ErrBadRequest       = errors.New("bad request")
	ErrNotFound         = errors.New("upload session not found")
	ErrForbidden        = errors.New("forbidden")
	ErrSessionExpired   = errors.New("upload session expired")
	ErrAlreadyCompleted = errors.New("upload session already completed")
)

// ErrorCode maps domain errors to API error codes.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrBadRequest):
		return "COMMON_BAD_PARAM"
	case errors.Is(err, ErrUnauthorized):
		return "UNAUTHORIZED"
	case errors.Is(err, ErrForbidden):
		return "FORBIDDEN"
	case errors.Is(err, ErrNotFound):
		return "COMMON_NOT_FOUND"
	case errors.Is(err, ErrSessionExpired):
		return "UPLOAD_SESSION_EXPIRED"
	case errors.Is(err, ErrAlreadyCompleted):
		return "UPLOAD_ALREADY_COMPLETED"
	default:
		return "COMMON_INTERNAL"
	}
}
