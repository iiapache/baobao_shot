package family

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/google/uuid"
)

// Service implements family CRUD with membership limits.
type Service struct {
	store        store.Store
	appScheme    string
	inviteSecret string
	now          func() time.Time
}

// NewService creates a family service backed by the given store.
func NewService(s store.Store, appScheme, inviteSecret string) *Service {
	if appScheme == "" {
		appScheme = "baobao://invite"
	}
	if inviteSecret == "" {
		inviteSecret = "dev-only-change-me"
	}
	return &Service{store: s, appScheme: appScheme, inviteSecret: inviteSecret, now: time.Now}
}

// SetNowForTest overrides the clock for unit tests.
func (s *Service) SetNowForTest(now time.Time) {
	s.now = func() time.Time { return now }
}

// CreateFamily creates a family when create/join limits allow.
func (s *Service) CreateFamily(ctx context.Context, userID, name, region string) (*model.Family, model.MemberRole, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, "", ErrInvalidName
	}
	region = strings.ToLower(strings.TrimSpace(region))
	if region != "cn" && region != "os" {
		return nil, "", ErrInvalidRegion
	}

	if err := s.checkCreateLimits(ctx, userID); err != nil {
		return nil, "", err
	}

	family, err := s.store.CreateFamily(ctx, store.CreateFamilyInput{
		ID:          "fam_" + uuid.NewString()[:12],
		Name:        name,
		AdminUserID: userID,
		Region:      region,
	})
	if err != nil {
		return nil, "", err
	}
	return family, model.MemberRoleAdmin, nil
}

// ListMine returns families the user actively belongs to.
func (s *Service) ListMine(ctx context.Context, userID string) ([]store.FamilySummary, error) {
	return s.store.ListUserFamilies(ctx, userID)
}

// GetDetail returns family detail for an active member.
func (s *Service) GetDetail(ctx context.Context, familyID, userID string) (*store.FamilyDetail, error) {
	detail, err := s.store.GetFamilyDetail(ctx, familyID, userID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	return detail, err
}

// UpdateName renames a family for any active member.
func (s *Service) UpdateName(ctx context.Context, familyID, userID, name string) (*model.Family, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, ErrInvalidName
	}
	family, err := s.store.UpdateFamilyName(ctx, familyID, userID, name)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	return family, err
}

// Dissolve deletes a family; only the admin may dissolve.
func (s *Service) Dissolve(ctx context.Context, familyID, userID string) error {
	detail, err := s.store.GetFamilyDetail(ctx, familyID, userID)
	if errors.Is(err, store.ErrNotFound) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if detail.Family.AdminUserID != userID {
		return ErrNotAdmin
	}
	if err := s.store.DeleteFamily(ctx, familyID, userID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrNotFound
		}
		if err.Error() == "not admin" {
			return ErrNotAdmin
		}
		return err
	}
	return nil
}

// CheckJoinLimit validates membership count before joining (for future invitation flow).
func (s *Service) CheckJoinLimit(ctx context.Context, userID string) error {
	count, err := s.store.CountActiveMemberships(ctx, userID)
	if err != nil {
		return err
	}
	if count >= MaxFamiliesJoined {
		return ErrJoinLimit
	}
	return nil
}

func (s *Service) checkCreateLimits(ctx context.Context, userID string) error {
	created, err := s.store.CountCreatedFamilies(ctx, userID)
	if err != nil {
		return err
	}
	if created >= MaxFamiliesCreated {
		return ErrCreateLimit
	}
	joined, err := s.store.CountActiveMemberships(ctx, userID)
	if err != nil {
		return err
	}
	if joined >= MaxFamiliesJoined {
		return ErrJoinLimit
	}
	return nil
}
