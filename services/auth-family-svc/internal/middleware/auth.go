package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/baobao/auth-family-svc/internal/auth"
)

type contextKey string

const (
	userIDKey contextKey = "userID"
	jtiKey    contextKey = "jti"
)

const defaultDevUserID = "usr_dev"

// AuthOptions configures JWT validation for the auth middleware.
type AuthOptions struct {
	Tokens *auth.TokenService
}

// Auth validates Bearer tokens (dev placeholders or signed JWT).
func Auth(opts AuthOptions) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
				token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
				if userID := parseDevToken(token); userID != "" {
					ctx := context.WithValue(r.Context(), userIDKey, userID)
					r = r.WithContext(ctx)
				} else if opts.Tokens != nil {
					claims, err := opts.Tokens.ValidateAccess(r.Context(), token)
					if err == nil {
						ctx := context.WithValue(r.Context(), userIDKey, claims.Subject)
						ctx = context.WithValue(ctx, jtiKey, claims.ID)
						if len(claims.Families) > 0 {
							ctx = WithFamilies(ctx, claims.Families)
						}
						r = r.WithContext(ctx)
					}
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

func parseDevToken(token string) string {
	if token == "" || token == "invalid" {
		return ""
	}
	if token == "dev" {
		return defaultDevUserID
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

// JTIFromContext returns the access token JTI when authenticated via JWT.
func JTIFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(jtiKey).(string)
	return id, ok && id != ""
}
