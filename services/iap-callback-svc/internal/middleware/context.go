package middleware

import (
	"context"
	"net/http"
	"strings"
)

type contextKey string

const regionKey contextKey = "region"

// RequestContext extracts gateway-forwarded headers.
func RequestContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		if region := strings.ToLower(strings.TrimSpace(r.Header.Get("X-Region"))); region != "" {
			ctx = context.WithValue(ctx, regionKey, region)
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// RegionFromContext returns the request region (cn/os).
func RegionFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(regionKey).(string)
	return v, ok
}
