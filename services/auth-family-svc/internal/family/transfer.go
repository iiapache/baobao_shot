package family

import (
	"context"
	"errors"

	"github.com/baobao/auth-family-svc/internal/model"
	"github.com/baobao/auth-family-svc/internal/store"
)

// TransferResult is returned after a successful admin transfer.
type TransferResult struct {
	FamilyID            string
	PreviousAdminUserID string
	NewAdminUserID      string
	TransferredAt       string
}

// TransferAdmin transfers family admin role from the current admin to a family member.
func (s *Service) TransferAdmin(ctx context.Context, familyID, adminUserID, targetUserID string) (*TransferResult, error) {
	if adminUserID == targetUserID {
		return nil, ErrTransferSelf
	}

	detail, err := s.store.GetFamilyDetail(ctx, familyID, adminUserID)
	if errors.Is(err, store.ErrNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if detail.Family.AdminUserID != adminUserID {
		return nil, ErrNotAdmin
	}

	if !isTransferTarget(detail.Members, targetUserID) {
		return nil, ErrTransferTargetInvalid
	}

	if err := s.store.TransferAdmin(ctx, familyID, adminUserID, targetUserID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, ErrNotFound
		}
		if err.Error() == "invalid transfer target" {
			return nil, ErrTransferTargetInvalid
		}
		return nil, err
	}

	now := s.now().UTC()
	return &TransferResult{
		FamilyID:            familyID,
		PreviousAdminUserID: adminUserID,
		NewAdminUserID:      targetUserID,
		TransferredAt:       now.Format("2006-01-02T15:04:05Z"),
	}, nil
}

func isTransferTarget(members []model.FamilyMember, targetUserID string) bool {
	for _, m := range members {
		if m.UserID == targetUserID && m.Role == model.MemberRoleFamily {
			return true
		}
	}
	return false
}
