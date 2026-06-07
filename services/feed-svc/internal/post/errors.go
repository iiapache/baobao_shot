package post

import "errors"

var (
	ErrUnauthorized    = errors.New("authentication required")
	ErrBadRequest      = errors.New("invalid request")
	ErrItemLimit       = errors.New("post item limit exceeded")
	ErrAuditRejected   = errors.New("ugc text rejected")
	ErrRateLimited     = errors.New("rate limited")
	ErrFamilyForbidden = errors.New("family publish forbidden")
	ErrNotFound        = errors.New("post not found")
	ErrForbidden       = errors.New("post forbidden")
)

// ErrorCode maps service errors to API error codes.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrUnauthorized):
		return "UNAUTHORIZED"
	case errors.Is(err, ErrBadRequest):
		return "COMMON_BAD_PARAM"
	case errors.Is(err, ErrItemLimit):
		return "POST_ITEM_LIMIT"
	case errors.Is(err, ErrAuditRejected):
		return "POST_AUDIT_REJECTED"
	case errors.Is(err, ErrRateLimited):
		return "COMMON_RATE_LIMIT"
	case errors.Is(err, ErrFamilyForbidden):
		return "POST_FAMILY_FORBIDDEN"
	case errors.Is(err, ErrNotFound):
		return "COMMON_NOT_FOUND"
	case errors.Is(err, ErrForbidden):
		return "COMMON_FORBIDDEN"
	default:
		return "SYS_INTERNAL"
	}
}
