package engagement

import "errors"

var (
	ErrUnauthorized    = errors.New("authentication required")
	ErrBadRequest      = errors.New("invalid request")
	ErrNotFound        = errors.New("post not found")
	ErrForbidden       = errors.New("forbidden")
	ErrAuditRejected   = errors.New("ugc text rejected")
	ErrFamilyForbidden = errors.New("family feed forbidden")
)

// ErrorCode maps service errors to API error codes.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrUnauthorized):
		return "UNAUTHORIZED"
	case errors.Is(err, ErrBadRequest):
		return "COMMON_BAD_PARAM"
	case errors.Is(err, ErrNotFound):
		return "COMMON_NOT_FOUND"
	case errors.Is(err, ErrForbidden):
		return "POST_FAMILY_FORBIDDEN"
	case errors.Is(err, ErrAuditRejected):
		return "POST_AUDIT_REJECTED"
	case errors.Is(err, ErrFamilyForbidden):
		return "POST_FAMILY_FORBIDDEN"
	default:
		return "SYS_INTERNAL"
	}
}
