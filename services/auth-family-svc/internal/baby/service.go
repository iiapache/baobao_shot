package baby

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
	"github.com/google/uuid"
)

// Service implements baby profile CRUD with family membership checks.
type Service struct {
	store store.Store
}

// NewService creates a baby service.
func NewService(s store.Store) *Service {
	return &Service{store: s}
}

// CreateInput holds create request fields from the handler layer.
type CreateInput struct {
	FamilyID    string
	UserID      string
	Name        string
	FullName    *string
	Gender      string
	Birthday    string
	BirthTime   *string
	BirthWeight *float64
	BirthLength *float64
	BirthPlace  *string
	DeviceTZ    string
}

// UpdateInput holds patch request fields from the handler layer.
type UpdateInput struct {
	BabyID      string
	UserID      string
	Name        *string
	FullName    *string
	Gender      *string
	Birthday    *string
	BirthTime   *string
	BirthWeight *float64
	BirthLength *float64
	BirthPlace  *string
	DeviceTZ    string
}

// Create adds a baby profile to a family when the caller is an active member.
func (s *Service) Create(ctx context.Context, in CreateInput) (*model.Baby, error) {
	if err := s.requireMember(ctx, in.FamilyID, in.UserID); err != nil {
		return nil, err
	}

	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, ErrInvalidName
	}
	gender, err := parseGender(in.Gender)
	if err != nil {
		return nil, err
	}
	birthDate, err := parseBirthDate(in.Birthday)
	if err != nil {
		return nil, err
	}
	var birthTime *time.Time
	if in.BirthTime != nil {
		birthTime, err = parseBirthTime(*in.BirthTime)
		if err != nil {
			return nil, err
		}
	}

	tz := ResolveTimezone(in.BirthPlace, in.DeviceTZ)
	baby, err := s.store.CreateBaby(ctx, store.CreateBabyInput{
		ID:          "bb_" + uuid.NewString()[:12],
		FamilyID:    in.FamilyID,
		Name:        name,
		FullName:    in.FullName,
		Gender:      gender,
		BirthDate:   birthDate,
		BirthTime:   birthTime,
		BirthWeight: in.BirthWeight,
		BirthLength: in.BirthLength,
		BirthPlace:  in.BirthPlace,
		Timezone:    tz,
	})
	if err != nil {
		return nil, err
	}
	return baby, nil
}

// ListByFamily returns active babies for a family when the caller is a member.
func (s *Service) ListByFamily(ctx context.Context, familyID, userID string) ([]model.Baby, error) {
	if err := s.requireMember(ctx, familyID, userID); err != nil {
		return nil, err
	}
	return s.store.ListBabiesByFamily(ctx, familyID)
}

// Get returns a baby when the caller belongs to its family.
func (s *Service) Get(ctx context.Context, babyID, userID string) (*model.Baby, error) {
	baby, err := s.store.GetBaby(ctx, babyID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if err := s.requireMember(ctx, baby.FamilyID, userID); err != nil {
		return nil, err
	}
	return baby, nil
}

// FamilyIDForBaby returns the family id for middleware role checks.
func (s *Service) FamilyIDForBaby(ctx context.Context, babyID string) (string, error) {
	baby, err := s.store.GetBaby(ctx, babyID)
	if errors.Is(err, store.ErrNotFound) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}
	return baby.FamilyID, nil
}

// Update patches a baby profile for an active family member.
func (s *Service) Update(ctx context.Context, in UpdateInput) (*model.Baby, error) {
	baby, err := s.Get(ctx, in.BabyID, in.UserID)
	if err != nil {
		return nil, err
	}

	patch := store.UpdateBabyInput{}
	if in.Name != nil {
		name := strings.TrimSpace(*in.Name)
		if name == "" {
			return nil, ErrInvalidName
		}
		patch.Name = &name
	}
	if in.FullName != nil {
		patch.FullName = in.FullName
	}
	if in.Gender != nil {
		gender, err := parseGender(*in.Gender)
		if err != nil {
			return nil, err
		}
		patch.Gender = &gender
	}
	if in.Birthday != nil {
		birthDate, err := parseBirthDate(*in.Birthday)
		if err != nil {
			return nil, err
		}
		patch.BirthDate = &birthDate
	}
	if in.BirthTime != nil {
		birthTime, err := parseBirthTime(*in.BirthTime)
		if err != nil {
			return nil, err
		}
		patch.BirthTime = birthTime
	}

	effectivePlace := baby.BirthPlace
	if in.BirthPlace != nil {
		patch.BirthPlace = in.BirthPlace
		effectivePlace = in.BirthPlace
	}
	if in.BirthWeight != nil {
		patch.BirthWeight = in.BirthWeight
	}
	if in.BirthLength != nil {
		patch.BirthLength = in.BirthLength
	}

	if in.BirthPlace != nil || in.DeviceTZ != "" {
		tz := ResolveTimezone(effectivePlace, in.DeviceTZ)
		patch.Timezone = &tz
	}

	updated, err := s.store.UpdateBaby(ctx, in.BabyID, patch)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	return updated, err
}

// Delete soft-deletes a baby profile for an active family member.
func (s *Service) Delete(ctx context.Context, babyID, userID string) error {
	if _, err := s.Get(ctx, babyID, userID); err != nil {
		return err
	}
	if err := s.store.SoftDeleteBaby(ctx, babyID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrNotFound
		}
		return err
	}
	return nil
}

// SetAvatarURL updates avatar_url after upload.
func (s *Service) SetAvatarURL(ctx context.Context, babyID, userID, avatarURL string) (*model.Baby, error) {
	if _, err := s.Get(ctx, babyID, userID); err != nil {
		return nil, err
	}
	updated, err := s.store.UpdateBaby(ctx, babyID, store.UpdateBabyInput{AvatarURL: &avatarURL})
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	return updated, err
}

func (s *Service) requireMember(ctx context.Context, familyID, userID string) error {
	_, err := s.store.GetFamilyDetail(ctx, familyID, userID)
	if errors.Is(err, store.ErrNotFound) {
		return ErrNotMember
	}
	return err
}

func parseGender(raw string) (model.BabyGender, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "unknown":
		return model.BabyGenderUnknown, nil
	case "male":
		return model.BabyGenderMale, nil
	case "female":
		return model.BabyGenderFemale, nil
	default:
		return "", ErrInvalidGender
	}
}

func parseBirthDate(raw string) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, ErrInvalidBirth
	}
	t, err := time.Parse("2006-01-02", raw)
	if err != nil {
		return time.Time{}, ErrInvalidBirth
	}
	return t, nil
}

func parseBirthTime(raw string) (*time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	for _, layout := range []string{"15:04", "15:04:05"} {
		if t, err := time.Parse(layout, raw); err == nil {
			return &t, nil
		}
	}
	return nil, ErrInvalidBirth
}
