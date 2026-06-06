package rest

import (
	"net/http"

	"github.com/baobao/auth-family-svc/internal/account"
	"github.com/baobao/auth-family-svc/internal/auth"
	"github.com/baobao/auth-family-svc/internal/backup"
	"github.com/baobao/auth-family-svc/internal/avatar"
	"github.com/baobao/auth-family-svc/internal/config"
	"github.com/baobao/auth-family-svc/internal/consent"
	"github.com/baobao/auth-family-svc/internal/middleware"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/go-chi/chi/v5"
)

// NewRouter builds the REST API router with health probes and API routes.
func NewRouter(cfg *config.Config, backend *store.Backend) http.Handler {
	if backend == nil {
		backend = &store.Backend{
			Store:        store.NewMemoryStore(),
			Verification: store.NewMemoryVerificationStore(),
		}
	}
	if cfg == nil {
		cfg = &config.Config{
			ServiceName:      "auth-family-svc",
			JWTSigningSecret: "dev-only-change-me",
		}
	}

	health := NewHealthHandler(cfg.ServiceName)
	families := NewFamilyHandler(cfg, backend.Store)
	babies := NewBabyHandler(backend.Store, avatar.NewLocalStorage(cfg.AvatarStoragePath, cfg.AvatarCDNBase))
	consentSvc := consent.NewService(backend.Store)
	accountSvc := account.NewService(backend.Store)
	accountHandler := NewAccountHandler(backend.Store, consentSvc, accountSvc)
	backupHandler := NewBackupHandler(backup.NewService(backend.Store))

	revocation := store.NewRevocationStore(cfg.RedisURL)
	issuer := auth.NewTokenIssuer(cfg.JWTSigningSecret)
	tokenSvc := auth.NewTokenService(issuer, revocation, backend.Store)

	authSvc := auth.NewService(backend.Store, auth.NewAppleVerifier(cfg.MockAppleVerify, cfg.AppleBundleID), tokenSvc)
	authHandler := NewAuthHandler(authSvc)
	phoneSvc := auth.NewPhoneAuthService(backend.Users(), backend.Verification, nil, tokenSvc)
	phoneHandler := NewPhoneAuthHandler(phoneSvc)
	sessionHandler := NewSessionHandler(tokenSvc)
	verifyHandler := NewVerifyHandler(tokenSvc)

	r := chi.NewRouter()
	r.Use(middleware.Tracing)
	r.Use(middleware.RequestContext)
	r.Use(middleware.Auth(middleware.AuthOptions{Tokens: tokenSvc}))

	r.Get("/health", health.Live)
	r.Get("/ready", health.Ready)

	// Gateway forward-auth — not exposed on public ingress paths
	r.Get("/internal/verify", verifyHandler.Verify)
	r.Post("/internal/verify", verifyHandler.Verify)

	r.Route("/v1/auth", func(r chi.Router) {
		r.Post("/apple", authHandler.AppleLogin)
		r.Post("/phone/code", phoneHandler.SendCode)
		r.Post("/phone/login", phoneHandler.Login)
		r.Post("/refresh", sessionHandler.Refresh)
	})

	r.Route("/v1/account", func(r chi.Router) {
		r.Get("/me", accountHandler.GetMe)
		r.Post("/consents/child-data", accountHandler.SubmitChildDataConsent)
		r.Post("/logout", sessionHandler.Logout)
		r.Delete("/", accountHandler.DeleteAccount)
		r.Post("/cancel-deletion", accountHandler.CancelDeletion)
		r.Post("/export", accountHandler.RequestExport)
	})

	r.Route("/v1/families", func(r chi.Router) {
		r.With(middleware.RequireChildConsent(consentSvc)).Post("/", families.Create)
		r.Get("/", families.ListMine)
		r.Route("/{familyId}", func(r chi.Router) {
			r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleGuest)).Get("/", families.Get)

			r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleMember)).Patch("/", families.Update)

			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleAdmin))
				r.Delete("/", families.Delete)
				r.Post("/invitations", families.CreateInvitation)
				r.Delete("/invitations/{code}", families.RevokeInvitation)
				r.Post("/transfer", families.TransferAdmin)
			})

			r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleMember)).
				Post("/takeover", families.Takeover)

			r.With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleGuest)).
				Get("/babies", babies.ListByFamily)
			r.With(middleware.RequireChildConsent(consentSvc)).
				With(middleware.RequireFamilyRole("familyId", middleware.FamilyRoleMember)).
				Post("/babies", babies.Create)
		})
	})

	r.Route("/v1/babies", func(r chi.Router) {
		r.Route("/{babyId}", func(r chi.Router) {
			r.With(middleware.RequireBabyFamilyRole(babies.Service(), "babyId", middleware.FamilyRoleGuest)).
				Get("/", babies.Get)
			r.With(middleware.RequireChildConsent(consentSvc)).
				With(middleware.RequireBabyFamilyRole(babies.Service(), "babyId", middleware.FamilyRoleMember)).
				Patch("/", babies.Update)
			r.With(middleware.RequireChildConsent(consentSvc)).
				With(middleware.RequireBabyFamilyRole(babies.Service(), "babyId", middleware.FamilyRoleMember)).
				Delete("/", babies.Delete)
			r.With(middleware.RequireChildConsent(consentSvc)).
				With(middleware.RequireBabyFamilyRole(babies.Service(), "babyId", middleware.FamilyRoleMember)).
				Post("/avatar", babies.UploadAvatar)
		})
	})

	r.Post("/v1/invitations/{code}/join", families.JoinInvitation)

	r.Route("/v1/backup", func(r chi.Router) {
		r.Post("/providers", backupHandler.BindProvider)
		r.Get("/providers", backupHandler.ListProviders)
		r.Delete("/providers/{id}", backupHandler.UnbindProvider)
		r.Get("/status", backupHandler.GetStatus)
		r.Post("/status", backupHandler.ReportStatus)
	})

	return r
}
