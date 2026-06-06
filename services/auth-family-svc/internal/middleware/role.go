package middleware

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const familiesKey contextKey = "families"

// FamilyRole is a membership role from the JWT families claim.
type FamilyRole string

const (
	FamilyRoleAdmin  FamilyRole = "admin"
	FamilyRoleMember FamilyRole = "family"
	FamilyRoleGuest  FamilyRole = "guest"
)

// FamiliesFromContext returns JWT family claims when present.
func FamiliesFromContext(ctx context.Context) ([]auth.FamilyClaim, bool) {
	claims, ok := ctx.Value(familiesKey).([]auth.FamilyClaim)
	return claims, ok
}

// WithFamilies attaches family claims to context (tests).
func WithFamilies(ctx context.Context, families []auth.FamilyClaim) context.Context {
	return context.WithValue(ctx, familiesKey, families)
}

// FamilyRoleForFamily resolves the caller role for a family from JWT claims.
func FamilyRoleForFamily(ctx context.Context, familyID string) (FamilyRole, bool) {
	families, ok := FamiliesFromContext(ctx)
	if !ok {
		return "", false
	}
	for _, f := range families {
		if f.FamilyID == familyID {
			return normalizeFamilyRole(FamilyRole(f.Role)), true
		}
	}
	return "", false
}

// RequireFamilyRole enforces a minimum role for routes scoped to {familyId}.
// When JWT families are absent (e.g. dev tokens), the check is skipped so service-layer guards still apply.
func RequireFamilyRole(familyIDParam string, minRole FamilyRole) func(http.Handler) http.Handler {
	minRole = normalizeFamilyRole(minRole)
	minLevel := roleLevel(minRole)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			families, ok := FamiliesFromContext(r.Context())
			if !ok || len(families) == 0 {
				next.ServeHTTP(w, r)
				return
			}

			familyID := chi.URLParam(r, familyIDParam)
			if familyID == "" {
				writeRoleError(w, r, http.StatusBadRequest, "COMMON_BAD_PARAM", "family id required")
				return
			}

			role, found := FamilyRoleForFamily(r.Context(), familyID)
			if !found {
				writeRoleError(w, r, http.StatusForbidden, "AUTH_FORBIDDEN", "not a member of this family")
				return
			}
			if roleLevel(role) < minLevel {
				writeRoleError(w, r, http.StatusForbidden, "FAMILY_FORBIDDEN", "insufficient family role")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// RequireRole is an alias for RequireFamilyRole with the default familyId param.
func RequireRole(minRole FamilyRole) func(http.Handler) http.Handler {
	return RequireFamilyRole("familyId", minRole)
}

func normalizeFamilyRole(role FamilyRole) FamilyRole {
	switch string(role) {
	case "admin":
		return FamilyRoleAdmin
	case "family", "member":
		return FamilyRoleMember
	case "guest", "visitor":
		return FamilyRoleGuest
	default:
		return role
	}
}

func roleLevel(role FamilyRole) int {
	switch normalizeFamilyRole(role) {
	case FamilyRoleAdmin:
		return 3
	case FamilyRoleMember:
		return 2
	case FamilyRoleGuest:
		return 1
	default:
		return 0
	}
}

func writeRoleError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	requestID := r.Header.Get("X-Request-Id")
	if requestID == "" {
		requestID = r.Header.Get("X-Trace-Id")
	}
	if requestID == "" {
		requestID = "req_" + uuid.NewString()[:8]
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"code":      code,
		"message":   message,
		"requestId": requestID,
	})
}
