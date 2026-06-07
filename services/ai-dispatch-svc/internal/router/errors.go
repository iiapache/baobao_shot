package router

import "errors"

const CodeModelFilingRequired = "AI_MODEL_FILING_REQUIRED"

// RouteError carries a stable API error code for routing failures.
type RouteError struct {
	Code    string
	Message string
}

func (e *RouteError) Error() string {
	if e.Message != "" {
		return e.Message
	}
	return e.Code
}

var (
	ErrNoAdapterAvailable  = errors.New("no adapter available for route request")
	ErrPlayNotAvailable    = errors.New("play not available in region")
	ErrInvalidRegion       = errors.New("invalid user region")
	ErrModelFilingRequired = &RouteError{
		Code:    CodeModelFilingRequired,
		Message: "CN model routing requires valid algorithm filing numbers",
	}
)

// ErrorCode returns the API error code for a routing error, or empty if unknown.
func ErrorCode(err error) string {
	var routeErr *RouteError
	if errors.As(err, &routeErr) {
		return routeErr.Code
	}
	return ""
}
