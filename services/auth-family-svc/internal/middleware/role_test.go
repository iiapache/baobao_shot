package middleware_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/middleware"
	"github.com/go-chi/chi/v5"
)

func TestRequireFamilyRoleAllowsSufficientRole(t *testing.T) {
	t.Parallel()

	r := chi.NewRouter()
	r.Route("/families/{familyId}", func(r chi.Router) {
		r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleAdmin)).Post("/transfer", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	})

	ctx := middleware.WithFamilies(context.Background(), []auth.FamilyClaim{
		{FamilyID: "fam_1", Role: "admin"},
	})
	req := httptest.NewRequest(http.MethodPost, "/families/fam_1/transfer", nil)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestRequireFamilyRoleRejectsNonAdminTransfer(t *testing.T) {
	t.Parallel()

	r := chi.NewRouter()
	r.Route("/families/{familyId}", func(r chi.Router) {
		r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleAdmin)).Post("/transfer", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	})

	ctx := middleware.WithFamilies(context.Background(), []auth.FamilyClaim{
		{FamilyID: "fam_1", Role: "family"},
	})
	req := httptest.NewRequest(http.MethodPost, "/families/fam_1/transfer", nil)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403", rec.Code)
	}
	if body := rec.Body.String(); !strings.Contains(body, "FAMILY_FORBIDDEN") || !strings.Contains(body, "insufficient family role") {
		t.Fatalf("body = %s", body)
	}
}

func TestRequireFamilyRoleRejectsGuestWrite(t *testing.T) {
	t.Parallel()

	r := chi.NewRouter()
	r.Route("/families/{familyId}", func(r chi.Router) {
		r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleMember)).Patch("/", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	})

	ctx := middleware.WithFamilies(context.Background(), []auth.FamilyClaim{
		{FamilyID: "fam_1", Role: "guest"},
	})
	req := httptest.NewRequest(http.MethodPatch, "/families/fam_1", nil)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403", rec.Code)
	}
	if body := rec.Body.String(); !strings.Contains(body, "FAMILY_FORBIDDEN") {
		t.Fatalf("body = %s", body)
	}
}

func TestRequireFamilyRoleRejectsNonMember(t *testing.T) {
	t.Parallel()

	r := chi.NewRouter()
	r.Route("/families/{familyId}", func(r chi.Router) {
		r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleGuest)).Get("/", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	})

	ctx := middleware.WithFamilies(context.Background(), []auth.FamilyClaim{
		{FamilyID: "fam_other", Role: "admin"},
	})
	req := httptest.NewRequest(http.MethodGet, "/families/fam_1", nil)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want 403", rec.Code)
	}
	if body := rec.Body.String(); !strings.Contains(body, "AUTH_FORBIDDEN") {
		t.Fatalf("body = %s", body)
	}
}

func TestRequireFamilyRoleSkipsWithoutJWTFamilies(t *testing.T) {
	t.Parallel()

	called := false
	handler := middleware.RequireFamilyRole("familyId", middleware.FamilyRoleAdmin)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	r := chi.NewRouter()
	r.Route("/families/{familyId}", func(r chi.Router) {
		r.Post("/transfer", handler.ServeHTTP)
	})

	req := httptest.NewRequest(http.MethodPost, "/families/fam_1/transfer", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if !called {
		t.Fatal("handler should run when JWT families are absent")
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestFamilyRoleForFamilyNormalizesAliases(t *testing.T) {
	t.Parallel()

	ctx := middleware.WithFamilies(context.Background(), []auth.FamilyClaim{
		{FamilyID: "fam_1", Role: "visitor"},
		{FamilyID: "fam_2", Role: "member"},
	})
	role, ok := middleware.FamilyRoleForFamily(ctx, "fam_1")
	if !ok || role != middleware.FamilyRoleGuest {
		t.Fatalf("visitor role = %q ok=%v", role, ok)
	}
	role, ok = middleware.FamilyRoleForFamily(ctx, "fam_2")
	if !ok || role != middleware.FamilyRoleMember {
		t.Fatalf("member role = %q ok=%v", role, ok)
	}
}
