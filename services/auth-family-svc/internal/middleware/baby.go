package middleware

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// BabyFamilyResolver resolves a baby id to its family id.
type BabyFamilyResolver interface {
	FamilyIDForBaby(ctx context.Context, babyID string) (string, error)
}

// RequireBabyFamilyRole enforces JWT family role for routes scoped to {babyId}.
func RequireBabyFamilyRole(resolver BabyFamilyResolver, babyIDParam string, minRole FamilyRole) func(http.Handler) http.Handler {
	minRole = normalizeFamilyRole(minRole)
	minLevel := roleLevel(minRole)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			families, ok := FamiliesFromContext(r.Context())
			if !ok || len(families) == 0 {
				next.ServeHTTP(w, r)
				return
			}

			babyID := chi.URLParam(r, babyIDParam)
			if babyID == "" {
				writeRoleError(w, r, http.StatusBadRequest, "COMMON_BAD_PARAM", "baby id required")
				return
			}

			familyID, err := resolver.FamilyIDForBaby(r.Context(), babyID)
			if err != nil {
				writeRoleError(w, r, http.StatusNotFound, "BABY_NOT_FOUND", "baby not found")
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
