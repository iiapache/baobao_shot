package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/middleware"
	"github.com/baobao/auth-family-svc/internal/store"
)

func TestJWTStoresFamiliesInContext(t *testing.T) {
	t.Parallel()

	issuer := auth.NewTokenIssuer("middleware-jwt-secret")
	tokenSvc := auth.NewTokenService(issuer, store.NewRevocationStore(""), nil)
	pair, err := issuer.Issue(auth.IssueTokenInput{
		UserID:   "usr_jwt",
		Region:   "cn",
		DeviceID: "dev-ctx",
		Families: []auth.FamilyClaim{{FamilyID: "fam_ctx", Role: "admin"}},
	})
	if err != nil {
		t.Fatal(err)
	}

	authMW := middleware.Auth(middleware.AuthOptions{Tokens: tokenSvc})
	var families []auth.FamilyClaim
	handler := authMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := middleware.FamiliesFromContext(r.Context())
		if ok {
			families = claims
		}
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)
	handler.ServeHTTP(httptest.NewRecorder(), req)

	if len(families) != 1 || families[0].FamilyID != "fam_ctx" || families[0].Role != "admin" {
		t.Fatalf("families = %+v", families)
	}
}

func TestDevTokenAuth(t *testing.T) {
	t.Parallel()
	auth := middleware.Auth(middleware.AuthOptions{})
	cases := []struct {
		auth   string
		wantID string
	}{
		{auth: "Bearer dev", wantID: "usr_dev"},
		{auth: "Bearer dev:usr_abc", wantID: "usr_abc"},
		{auth: "Bearer atk_usr_01HZ_suffix", wantID: "usr_01HZ"},
		{auth: "Bearer invalid", wantID: ""},
	}

	for _, tc := range cases {
		var got string
		handler := auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id, ok := middleware.UserIDFromContext(r.Context())
			if ok {
				got = id
			}
		}))

		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", tc.auth)
		handler.ServeHTTP(httptest.NewRecorder(), req)

		if got != tc.wantID {
			t.Fatalf("auth %q: got %q want %q", tc.auth, got, tc.wantID)
		}
	}
}
