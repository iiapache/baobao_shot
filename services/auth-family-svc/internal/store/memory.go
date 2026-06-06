package store

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

// MemoryStore is an in-memory Store for dev and unit tests.
type MemoryStore struct {
	mu            sync.RWMutex
	users         map[string]*model.User
	usersByApple  map[string]string
	usersByPhone  map[string]string // phone|region -> user id
	families      map[string]*model.Family
	memberships   map[string]map[string]*model.Membership // userID -> familyID -> membership
	inviteCodes      map[string]*model.InviteCode
	childConsents    map[string]*model.ChildConsent // userID|version -> consent
	accountDeletions map[string]*model.AccountDeletion
	exportRequests   map[string]*model.DataExportRequest // exportID -> request
	pendingExports   map[string]string                   // userID -> exportID
	babies           map[string]*model.Baby
	backupProviders  map[string]*model.BackupProvider
	backupByUserKind map[string]string
	backupStatus     map[string]*model.BackupStatus
	takeoverVotes    map[string]*model.TakeoverVote
	takeoverBallots  map[string]map[string]*model.TakeoverBallot
}

// NewMemoryStore returns an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:         make(map[string]*model.User),
		usersByApple:  make(map[string]string),
		usersByPhone:  make(map[string]string),
		families:      make(map[string]*model.Family),
		memberships:   make(map[string]map[string]*model.Membership),
		inviteCodes:      make(map[string]*model.InviteCode),
		childConsents:    make(map[string]*model.ChildConsent),
		accountDeletions: make(map[string]*model.AccountDeletion),
		exportRequests:   make(map[string]*model.DataExportRequest),
		pendingExports:   make(map[string]string),
		babies:           make(map[string]*model.Baby),
		backupProviders:  make(map[string]*model.BackupProvider),
		backupByUserKind: make(map[string]string),
		backupStatus:     make(map[string]*model.BackupStatus),
		takeoverVotes:    make(map[string]*model.TakeoverVote),
		takeoverBallots:  make(map[string]map[string]*model.TakeoverBallot),
	}
}

func (s *MemoryStore) Ping(_ context.Context) error { return nil }

func (s *MemoryStore) FindByID(_ context.Context, userID string) (*model.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	user, ok := s.users[userID]
	if !ok || user.DeletedAt != nil {
		return nil, ErrNotFound
	}
	return cloneUser(user), nil
}

func (s *MemoryStore) FindByAppleSub(_ context.Context, appleSub string) (*model.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	id, ok := s.usersByApple[appleSub]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneUser(s.users[id]), nil
}

func (s *MemoryStore) CreateUser(_ context.Context, in CreateUserInput) (*model.User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.usersByApple[in.AppleSub]; ok {
		return nil, ErrDuplicateAppleSub
	}
	now := time.Now().UTC()
	user := &model.User{
		ID:         in.ID,
		AppleSub:   &in.AppleSub,
		Region:     in.Region,
		Nickname:   in.Nickname,
		Status:     model.UserStatusActive,
		CreatedAt:  now,
		UpdatedAt:  now,
		LastSeenAt: now,
	}
	s.users[in.ID] = user
	s.usersByApple[in.AppleSub] = in.ID
	return cloneUser(user), nil
}

func (s *MemoryStore) FindByPhone(_ context.Context, phone, region string) (*model.User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	id, ok := s.usersByPhone[phoneRegionKey(phone, region)]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneUser(s.users[id]), nil
}

func (s *MemoryStore) CreatePhoneUser(_ context.Context, in CreatePhoneUserInput) (*model.User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := phoneRegionKey(in.Phone, in.Region)
	if _, ok := s.usersByPhone[key]; ok {
		return nil, ErrDuplicatePhone
	}
	now := time.Now().UTC()
	phone := in.Phone
	user := &model.User{
		ID:         in.ID,
		Phone:      &phone,
		Region:     in.Region,
		Nickname:   in.Nickname,
		Status:     model.UserStatusActive,
		CreatedAt:  now,
		UpdatedAt:  now,
		LastSeenAt: now,
	}
	s.users[in.ID] = user
	s.usersByPhone[key] = in.ID
	return cloneUser(user), nil
}

func (s *MemoryStore) TouchLastSeen(_ context.Context, userID string) (*model.User, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	user, ok := s.users[userID]
	if !ok || user.DeletedAt != nil {
		return nil, ErrNotFound
	}
	now := time.Now().UTC()
	user.LastSeenAt = now
	user.UpdatedAt = now
	return cloneUser(user), nil
}

func (s *MemoryStore) CountCreatedFamilies(_ context.Context, userID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	count := 0
	for _, f := range s.families {
		if f.AdminUserID == userID {
			count++
		}
	}
	return count, nil
}

func (s *MemoryStore) CountActiveMemberships(_ context.Context, userID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return countActiveMembershipsLocked(s, userID), nil
}

func (s *MemoryStore) CreateFamily(_ context.Context, in CreateFamilyInput) (*model.Family, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	family := &model.Family{
		ID:          in.ID,
		Name:        in.Name,
		AdminUserID: in.AdminUserID,
		Region:      in.Region,
		Plan:        "free",
		CreatedAt:   now,
	}
	s.families[in.ID] = family
	if s.memberships[in.AdminUserID] == nil {
		s.memberships[in.AdminUserID] = make(map[string]*model.Membership)
	}
	s.memberships[in.AdminUserID][in.ID] = &model.Membership{
		UserID:   in.AdminUserID,
		FamilyID: in.ID,
		Role:     model.MemberRoleAdmin,
		JoinedAt: now,
	}
	return cloneFamily(family), nil
}

func (s *MemoryStore) ListUserFamilies(_ context.Context, userID string) ([]FamilySummary, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	byFamily, ok := s.memberships[userID]
	if !ok {
		return []FamilySummary{}, nil
	}
	out := make([]FamilySummary, 0, len(byFamily))
	for familyID, m := range byFamily {
		if m.RemovedAt != nil {
			continue
		}
		f, ok := s.families[familyID]
		if !ok {
			continue
		}
		out = append(out, FamilySummary{Family: *cloneFamily(f), Role: m.Role})
	}
	return out, nil
}

func (s *MemoryStore) GetFamilyDetail(_ context.Context, familyID, userID string) (*FamilyDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	f, ok := s.families[familyID]
	if !ok {
		return nil, ErrNotFound
	}
	m, ok := activeMembershipLocked(s, userID, familyID)
	if !ok {
		return nil, ErrNotFound
	}
	members := listMembersLocked(s, familyID)
	return &FamilyDetail{
		Family:  *cloneFamily(f),
		Role:    m.Role,
		Members: members,
	}, nil
}

func (s *MemoryStore) UpdateFamilyName(_ context.Context, familyID, userID, name string) (*model.Family, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.families[familyID]
	if !ok {
		return nil, ErrNotFound
	}
	if _, ok := activeMembershipLocked(s, userID, familyID); !ok {
		return nil, ErrNotFound
	}
	f.Name = name
	return cloneFamily(f), nil
}

func (s *MemoryStore) DeleteFamily(_ context.Context, familyID, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.families[familyID]
	if !ok {
		return ErrNotFound
	}
	if f.AdminUserID != userID {
		return fmt.Errorf("not admin")
	}
	delete(s.families, familyID)
	for uid, byFamily := range s.memberships {
		delete(byFamily, familyID)
		if len(byFamily) == 0 {
			delete(s.memberships, uid)
		}
	}
	return nil
}

func (s *MemoryStore) AddMembership(_ context.Context, m model.Membership) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.families[m.FamilyID]; !ok {
		return ErrNotFound
	}
	if s.memberships[m.UserID] == nil {
		s.memberships[m.UserID] = make(map[string]*model.Membership)
	}
	copy := m
	if copy.JoinedAt.IsZero() {
		copy.JoinedAt = time.Now().UTC()
	}
	s.memberships[m.UserID][m.FamilyID] = &copy
	return nil
}

func countActiveMembershipsLocked(s *MemoryStore, userID string) int {
	byFamily, ok := s.memberships[userID]
	if !ok {
		return 0
	}
	count := 0
	for _, m := range byFamily {
		if m.RemovedAt == nil {
			count++
		}
	}
	return count
}

func activeMembershipLocked(s *MemoryStore, userID, familyID string) (*model.Membership, bool) {
	byFamily, ok := s.memberships[userID]
	if !ok {
		return nil, false
	}
	m, ok := byFamily[familyID]
	if !ok || m.RemovedAt != nil {
		return nil, false
	}
	return m, true
}

func listMembersLocked(s *MemoryStore, familyID string) []model.FamilyMember {
	out := make([]model.FamilyMember, 0)
	for userID, byFamily := range s.memberships {
		m, ok := byFamily[familyID]
		if !ok || m.RemovedAt != nil {
			continue
		}
		out = append(out, model.FamilyMember{
			UserID:   userID,
			Role:     m.Role,
			Nickname: m.Nickname,
			JoinedAt: m.JoinedAt,
		})
	}
	return out
}

func phoneRegionKey(phone, region string) string {
	return phone + "|" + region
}

func cloneUser(u *model.User) *model.User {
	if u == nil {
		return nil
	}
	copy := *u
	if u.AppleSub != nil {
		v := *u.AppleSub
		copy.AppleSub = &v
	}
	if u.Phone != nil {
		v := *u.Phone
		copy.Phone = &v
	}
	if u.AvatarURL != nil {
		v := *u.AvatarURL
		copy.AvatarURL = &v
	}
	if u.ChildDataConsentAt != nil {
		v := *u.ChildDataConsentAt
		copy.ChildDataConsentAt = &v
	}
	if u.DeletedAt != nil {
		v := *u.DeletedAt
		copy.DeletedAt = &v
	}
	return &copy
}

func cloneFamily(f *model.Family) *model.Family {
	if f == nil {
		return nil
	}
	copy := *f
	return &copy
}

func (s *MemoryStore) CountFamilyMembers(_ context.Context, familyID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return countFamilyMembersLocked(s, familyID), nil
}

func (s *MemoryStore) CreateInviteCode(_ context.Context, in CreateInviteCodeInput) (*model.InviteCode, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	invite := &model.InviteCode{
		Code:      in.Code,
		FamilyID:  in.FamilyID,
		CreatedBy: in.CreatedBy,
		ExpireAt:  in.ExpireAt.UTC(),
		MaxUses:   in.MaxUses,
		UsedCount: 0,
		CreatedAt: now,
	}
	s.inviteCodes[in.Code] = invite
	return cloneInviteCode(invite), nil
}

func (s *MemoryStore) GetInviteCode(_ context.Context, code string) (*model.InviteCode, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	invite, ok := s.inviteCodes[code]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneInviteCode(invite), nil
}

func (s *MemoryStore) InviteCodeExists(_ context.Context, code string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.inviteCodes[code]
	return ok, nil
}

func (s *MemoryStore) RevokeInviteCode(_ context.Context, familyID, code string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	invite, ok := s.inviteCodes[code]
	if !ok || invite.FamilyID != familyID {
		return ErrNotFound
	}
	if invite.RevokedAt != nil {
		return nil
	}
	now := time.Now().UTC()
	invite.RevokedAt = &now
	return nil
}

func (s *MemoryStore) JoinViaInvite(_ context.Context, in JoinViaInviteInput) (*JoinViaInviteResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	invite, ok := s.inviteCodes[in.Code]
	if !ok {
		return nil, ErrNotFound
	}
	if err := validateInviteForJoin(invite); err != nil {
		return nil, err
	}
	if countFamilyMembersLocked(s, invite.FamilyID) >= 8 {
		return nil, ErrMemberLimit
	}
	if _, ok := activeMembershipLocked(s, in.UserID, invite.FamilyID); ok {
		return nil, ErrAlreadyMember
	}
	if _, ok := s.families[invite.FamilyID]; !ok {
		return nil, ErrNotFound
	}

	joinedAt := time.Now().UTC()
	if s.memberships[in.UserID] == nil {
		s.memberships[in.UserID] = make(map[string]*model.Membership)
	}
	s.memberships[in.UserID][invite.FamilyID] = &model.Membership{
		UserID:   in.UserID,
		FamilyID: invite.FamilyID,
		Role:     model.MemberRoleFamily,
		Nickname: in.Nickname,
		JoinedAt: joinedAt,
	}
	invite.UsedCount++

	return &JoinViaInviteResult{
		FamilyID: invite.FamilyID,
		Role:     model.MemberRoleFamily,
		JoinedAt: joinedAt,
	}, nil
}

func countFamilyMembersLocked(s *MemoryStore, familyID string) int {
	count := 0
	for _, byFamily := range s.memberships {
		m, ok := byFamily[familyID]
		if ok && m.RemovedAt == nil {
			count++
		}
	}
	return count
}

func cloneInviteCode(invite *model.InviteCode) *model.InviteCode {
	if invite == nil {
		return nil
	}
	copy := *invite
	if invite.RevokedAt != nil {
		t := *invite.RevokedAt
		copy.RevokedAt = &t
	}
	return &copy
}

func consentKey(userID, version string) string {
	return userID + "|" + version
}

func (s *MemoryStore) RecordChildConsent(_ context.Context, in RecordChildConsentInput) (*model.ChildConsent, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	user, ok := s.users[in.UserID]
	if !ok || user.DeletedAt != nil {
		return nil, ErrNotFound
	}

	agreedAt := in.AgreedAt.UTC()
	record := &model.ChildConsent{
		UserID:   in.UserID,
		Version:  in.Version,
		AgreedAt: agreedAt,
		IP:       in.IP,
		DeviceID: in.DeviceID,
	}
	s.childConsents[consentKey(in.UserID, in.Version)] = record
	user.ChildDataConsentAt = &agreedAt
	user.UpdatedAt = agreedAt
	return cloneChildConsent(record), nil
}

func (s *MemoryStore) HasChildConsent(_ context.Context, userID, version string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.childConsents[consentKey(userID, version)]
	return ok, nil
}

func cloneChildConsent(c *model.ChildConsent) *model.ChildConsent {
	if c == nil {
		return nil
	}
	copy := *c
	copy.AgreedAt = c.AgreedAt.UTC()
	return &copy
}
