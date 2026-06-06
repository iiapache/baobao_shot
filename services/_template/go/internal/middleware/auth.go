package middleware

import (
	"context"
	"net/http"
	"strings"
)

type contextKey string

const userIDKey contextKey = "userID"

// Auth is a placeholder middleware for gateway-forwarded JWT validation.
// Production: verify signature, expiry, and inject claims into context.
func Auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		if auth != "" && strings.HasPrefix(auth, "Bearer ") {
			// Placeholder: extract subject after real JWT validation in auth-family-svc era.
			token := strings.TrimPrefix(auth, "Bearer ")
			if token != "" && token != "invalid" {
				ctx := context.WithValue(r.Context(), userIDKey, "placeholder-user")
				r = r.WithContext(ctx)
			}
		}
		next.ServeHTTP(w, r)
	})
}

// UserIDFromContext returns the authenticated user id if present.
func UserIDFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok
}
