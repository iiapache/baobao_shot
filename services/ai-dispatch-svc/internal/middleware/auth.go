package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/auth"
)

type contextKey string

const (
	userIDKey contextKey = "userID"
	regionKey contextKey = "region"
)

// AuthOptions configures JWT validation for the auth middleware.
type AuthOptions struct {
	Validator *auth.Validator
}

// Auth validates Bearer tokens (dev placeholders or signed JWT).
func Auth(opts AuthOptions) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
				token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
				if userID := auth.ParseDevToken(token); userID != "" {
					ctx := context.WithValue(r.Context(), userIDKey, userID)
					r = r.WithContext(ctx)
				} else if opts.Validator != nil {
					claims, err := opts.Validator.ParseAccess(token)
					if err == nil {
						ctx := context.WithValue(r.Context(), userIDKey, claims.Subject)
						if claims.Region != "" {
							ctx = context.WithValue(ctx, regionKey, strings.ToLower(claims.Region))
						}
						r = r.WithContext(ctx)
					}
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

// UserIDFromContext returns the authenticated user id if present.
func UserIDFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok && id != ""
}

// RequestContext extracts gateway-forwarded headers.
func RequestContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		if _, ok := RegionFromContext(ctx); !ok {
			if region := strings.ToLower(strings.TrimSpace(r.Header.Get("X-Region"))); region != "" {
				ctx = context.WithValue(ctx, regionKey, region)
			}
		}
		if appVersion := strings.TrimSpace(r.Header.Get("X-App-Version")); appVersion != "" {
			ctx = context.WithValue(ctx, appVersionKey, appVersion)
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

const appVersionKey contextKey = "appVersion"

// RegionFromContext returns the request region (cn/os).
func RegionFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(regionKey).(string)
	return v, ok && v != ""
}

// AppVersionFromContext returns the client app version if present.
func AppVersionFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(appVersionKey).(string)
	return v, ok && v != ""
}
