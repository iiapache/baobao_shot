package middleware

import (
	"context"
	"net/http"
	"strings"
)

type contextKey string

const userIDKey contextKey = "userID"

// Auth extracts the authenticated user from gateway-forwarded headers or dev Bearer tokens.
func Auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if userID := strings.TrimSpace(r.Header.Get("X-User-Id")); userID != "" {
			ctx := context.WithValue(r.Context(), userIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		authHeader := r.Header.Get("Authorization")
		if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
			token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
			if userID := parseDevToken(token); userID != "" {
				ctx := context.WithValue(r.Context(), userIDKey, userID)
				r = r.WithContext(ctx)
			}
		}
		next.ServeHTTP(w, r)
	})
}

func parseDevToken(token string) string {
	if token == "" || token == "invalid" {
		return ""
	}
	if token == "dev" {
		return "usr_dev"
	}
	if strings.HasPrefix(token, "dev:") {
		return strings.TrimPrefix(token, "dev:")
	}
	if strings.HasPrefix(token, "atk_") {
		body := strings.TrimPrefix(token, "atk_")
		if idx := strings.LastIndex(body, "_"); idx > 0 {
			return body[:idx]
		}
	}
	return ""
}

// UserIDFromContext returns the authenticated user id if present.
func UserIDFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok && id != ""
}
