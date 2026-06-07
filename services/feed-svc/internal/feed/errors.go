package feed

import "errors"

var (
	ErrUnauthorized    = errors.New("authentication required")
	ErrBadRequest      = errors.New("invalid request")
	ErrFamilyForbidden = errors.New("family feed forbidden")
	ErrInvalidCursor   = errors.New("invalid pagination cursor")
)

// ErrorCode maps service errors to API error codes.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrUnauthorized):
		return "UNAUTHORIZED"
	case errors.Is(err, ErrBadRequest):
		return "COMMON_BAD_PARAM"
	case errors.Is(err, ErrFamilyForbidden):
		return "POST_FAMILY_FORBIDDEN"
	case errors.Is(err, ErrInvalidCursor):
		return "COMMON_BAD_PARAM"
	default:
		return "SYS_INTERNAL"
	}
}
