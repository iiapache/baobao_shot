package family

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

// CreateInvitation generates a new invite code for a family admin.
func (s *Service) CreateInvitation(ctx context.Context, familyID, adminUserID string) (*model.InviteCode, QRPayload, error) {
	detail, err := s.store.GetFamilyDetail(ctx, familyID, adminUserID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, QRPayload{}, ErrNotFound
	}
	if err != nil {
		return nil, QRPayload{}, err
	}
	if detail.Family.AdminUserID != adminUserID {
		return nil, QRPayload{}, ErrNotAdmin
	}

	expireAt := time.Now().UTC().Add(InviteTTL)
	var invite *model.InviteCode
	for attempt := 0; attempt < 10; attempt++ {
		code, err := GenerateInviteCode()
		if err != nil {
			return nil, QRPayload{}, err
		}
		exists, err := s.store.InviteCodeExists(ctx, code)
		if err != nil {
			return nil, QRPayload{}, err
		}
		if exists {
			continue
		}
		invite, err = s.store.CreateInviteCode(ctx, store.CreateInviteCodeInput{
			Code:      code,
			FamilyID:  familyID,
			CreatedBy: adminUserID,
			ExpireAt:  expireAt,
			MaxUses:   InviteMaxUses,
		})
		if err != nil {
			return nil, QRPayload{}, err
		}
		payload := SignInvitePayload(s.appScheme, invite.Code, s.inviteSecret)
		return invite, payload, nil
	}
	return nil, QRPayload{}, errors.New("failed to generate unique invite code")
}

// RevokeInvitation marks an invite code as revoked; admin only.
func (s *Service) RevokeInvitation(ctx context.Context, familyID, adminUserID, code string) error {
	detail, err := s.store.GetFamilyDetail(ctx, familyID, adminUserID)
	if errors.Is(err, store.ErrNotFound) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if detail.Family.AdminUserID != adminUserID {
		return ErrNotAdmin
	}

	invite, err := s.store.GetInviteCode(ctx, code)
	if errors.Is(err, store.ErrNotFound) {
		return ErrInviteNotFound
	}
	if err != nil {
		return err
	}
	if invite.FamilyID != familyID {
		return ErrInviteNotFound
	}
	if invite.RevokedAt != nil {
		return nil
	}
	return s.store.RevokeInviteCode(ctx, familyID, code)
}

// JoinViaInvitation adds the user to the family behind an invite code.
func (s *Service) JoinViaInvitation(ctx context.Context, code, userID, relation, nickname string) (*store.JoinViaInviteResult, error) {
	relation = strings.TrimSpace(relation)
	nickname = strings.TrimSpace(nickname)
	if relation == "" {
		return nil, ErrInvalidRelation
	}
	displayName := nickname
	if displayName == "" {
		displayName = relation
	}

	if err := s.CheckJoinLimit(ctx, userID); err != nil {
		return nil, err
	}

	invite, err := s.store.GetInviteCode(ctx, code)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrInviteNotFound
	}
	if err != nil {
		return nil, err
	}
	if err := validateInviteActive(invite); err != nil {
		return nil, err
	}

	memberCount, err := s.store.CountFamilyMembers(ctx, invite.FamilyID)
	if err != nil {
		return nil, err
	}
	if memberCount >= MaxFamilyMembers {
		return nil, ErrMemberLimit
	}

	result, err := s.store.JoinViaInvite(ctx, store.JoinViaInviteInput{
		Code:     code,
		UserID:   userID,
		Nickname: displayName,
	})
	if err != nil {
		switch {
		case errors.Is(err, store.ErrNotFound):
			return nil, ErrInviteNotFound
		case errors.Is(err, store.ErrInviteExpired):
			return nil, ErrInviteExpired
		case errors.Is(err, store.ErrInviteUsedUp):
			return nil, ErrInviteUsedUp
		case errors.Is(err, store.ErrAlreadyMember):
			return nil, ErrAlreadyMember
		case errors.Is(err, store.ErrMemberLimit):
			return nil, ErrMemberLimit
		default:
			return nil, err
		}
	}
	return result, nil
}

func validateInviteActive(invite *model.InviteCode) error {
	now := time.Now().UTC()
	if invite.RevokedAt != nil {
		return ErrInviteExpired
	}
	if !invite.ExpireAt.After(now) {
		return ErrInviteExpired
	}
	if invite.UsedCount >= invite.MaxUses {
		return ErrInviteUsedUp
	}
	return nil
}
