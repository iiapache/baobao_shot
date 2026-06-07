package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
)

const familiesKey contextKey = "families"

// FamilyClaim is a family membership entry from gateway JWT or X-Families header.
type FamilyClaim struct {
	FamilyID string `json:"familyId"`
	Role     string `json:"role"`
}

// FamiliesFromContext returns family claims when present.
func FamiliesFromContext(ctx context.Context) ([]FamilyClaim, bool) {
	claims, ok := ctx.Value(familiesKey).([]FamilyClaim)
	return claims, ok
}

// WithFamilies attaches family claims to context (tests).
func WithFamilies(ctx context.Context, families []FamilyClaim) context.Context {
	return context.WithValue(ctx, familiesKey, families)
}

// FamilyContext parses gateway-forwarded X-Families JSON into request context.
func FamilyContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := strings.TrimSpace(r.Header.Get("X-Families"))
		if raw != "" {
			var families []FamilyClaim
			if err := json.Unmarshal([]byte(raw), &families); err == nil && len(families) > 0 {
				ctx := context.WithValue(r.Context(), familiesKey, families)
				r = r.WithContext(ctx)
			}
		}
		next.ServeHTTP(w, r)
	})
}
