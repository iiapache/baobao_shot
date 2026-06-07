package store

import (
	"context"
	"errors"
	"time"

	"github.com/baobao/auth-family-svc/internal/model"
)

var (
	// ErrNotFound is returned when a record does not exist.
	ErrNotFound = errors.New("not found")
	// ErrDuplicateAppleSub is returned when apple_sub unique constraint is violated.
	ErrDuplicateAppleSub = errors.New("duplicate apple_sub")
	// ErrDuplicatePhone is returned when phone+region unique constraint is violated.
	ErrDuplicatePhone = errors.New("duplicate phone")
	// ErrInviteExpired is returned when an invite code is expired or revoked.
	ErrInviteExpired = errors.New("invite expired")
	// ErrInviteUsedUp is returned when an invite code has no remaining uses.
	ErrInviteUsedUp = errors.New("invite used up")
	// ErrAlreadyMember is returned when the user is already in the family.
	ErrAlreadyMember = errors.New("already a family member")
	// ErrMemberLimit is returned when the family member cap is reached.
	ErrMemberLimit = errors.New("family member limit reached")
	// ErrDeletionNotPending is returned when no active deletion request exists.
	ErrDeletionNotPending = errors.New("deletion not pending")
	// ErrDeletionExpired is returned when the deletion grace period has elapsed.
	ErrDeletionExpired = errors.New("deletion grace period expired")
	// ErrTakeoverInProgress is returned when a family already has an active takeover vote.
	ErrTakeoverInProgress = errors.New("takeover already in progress")
	// ErrTakeoverAlreadyVoted is returned when a member already cast a ballot.
	ErrTakeoverAlreadyVoted = errors.New("already voted on takeover")
)

// CreateUserInput holds fields for a new Apple sign-in registration.
type CreateUserInput struct {
	ID       string
	AppleSub string
	Region   string
	Nickname string
}

// CreatePhoneUserInput holds fields for phone sign-in registration.
type CreatePhoneUserInput struct {
	ID       string
	Phone    string
	Region   string
	Nickname string
}

// UserStore persists and queries user records.
type UserStore interface {
	FindByID(ctx context.Context, userID string) (*model.User, error)
	FindByAppleSub(ctx context.Context, appleSub string) (*model.User, error)
	FindByPhone(ctx context.Context, phone, region string) (*model.User, error)
	CreateUser(ctx context.Context, in CreateUserInput) (*model.User, error)
	CreatePhoneUser(ctx context.Context, in CreatePhoneUserInput) (*model.User, error)
	TouchLastSeen(ctx context.Context, userID string) (*model.User, error)
}

// RecordChildConsentInput holds fields for recording child-data consent.
type RecordChildConsentInput struct {
	UserID   string
	Version  string
	AgreedAt time.Time
	IP       string
	DeviceID string
}

// ConsentStore persists versioned child-data consent records.
type ConsentStore interface {
	RecordChildConsent(ctx context.Context, in RecordChildConsentInput) (*model.ChildConsent, error)
	HasChildConsent(ctx context.Context, userID, version string) (bool, error)
	GetLatestChildConsent(ctx context.Context, userID string) (*model.ChildConsent, error)
}

// CreateFamilyInput holds fields for creating a family.
type CreateFamilyInput struct {
	ID          string
	Name        string
	AdminUserID string
	Region      string
}

// FamilySummary is a family list item with the caller's role.
type FamilySummary struct {
	Family model.Family
	Role   model.MemberRole
}

// FamilyDetail is the full family view for an authorized member.
type FamilyDetail struct {
	Family  model.Family
	Role    model.MemberRole
	Members []model.FamilyMember
}

// CreateInviteCodeInput holds fields for a new invite code.
type CreateInviteCodeInput struct {
	Code      string
	FamilyID  string
	CreatedBy string
	ExpireAt  time.Time
	MaxUses   int
}

// JoinViaInviteInput holds fields for joining a family via invite code.
type JoinViaInviteInput struct {
	Code     string
	UserID   string
	Nickname string
}

// JoinViaInviteResult is returned after a successful invite join.
type JoinViaInviteResult struct {
	FamilyID string
	Role     model.MemberRole
	JoinedAt time.Time
}

// FamilyStore persists family groups and memberships.
type FamilyStore interface {
	CountCreatedFamilies(ctx context.Context, userID string) (int, error)
	CountActiveMemberships(ctx context.Context, userID string) (int, error)
	CountFamilyMembers(ctx context.Context, familyID string) (int, error)
	CreateFamily(ctx context.Context, in CreateFamilyInput) (*model.Family, error)
	ListUserFamilies(ctx context.Context, userID string) ([]FamilySummary, error)
	GetFamilyDetail(ctx context.Context, familyID, userID string) (*FamilyDetail, error)
	UpdateFamilyName(ctx context.Context, familyID, userID, name string) (*model.Family, error)
	DeleteFamily(ctx context.Context, familyID, userID string) error
	// AddMembership inserts a membership (used by tests and future join flow).
	AddMembership(ctx context.Context, m model.Membership) error
	CreateInviteCode(ctx context.Context, in CreateInviteCodeInput) (*model.InviteCode, error)
	GetInviteCode(ctx context.Context, code string) (*model.InviteCode, error)
	RevokeInviteCode(ctx context.Context, familyID, code string) error
	JoinViaInvite(ctx context.Context, in JoinViaInviteInput) (*JoinViaInviteResult, error)
	InviteCodeExists(ctx context.Context, code string) (bool, error)
	TransferAdmin(ctx context.Context, familyID, fromUserID, toUserID string) error
	CreateTakeoverVote(ctx context.Context, vote model.TakeoverVote) (*model.TakeoverVote, error)
	GetActiveTakeoverVote(ctx context.Context, familyID string) (*model.TakeoverVote, error)
	CastTakeoverBallot(ctx context.Context, voteID, userID string, choice model.TakeoverBallotChoice, votedAt time.Time) error
	ListTakeoverBallots(ctx context.Context, voteID string) ([]model.TakeoverBallot, error)
	UpdateTakeoverVote(ctx context.Context, voteID string, status model.TakeoverVoteStatus, endsAt, completedAt *time.Time) error
	ListDueTakeoverVotes(ctx context.Context, before time.Time) ([]model.TakeoverVote, error)
	CompleteTakeover(ctx context.Context, voteID, newAdminUserID string, completedAt time.Time) error
}

// CreateBabyInput holds fields for creating a baby profile.
type CreateBabyInput struct {
	ID          string
	FamilyID    string
	Name        string
	FullName    *string
	Gender      model.BabyGender
	BirthDate   time.Time
	BirthTime   *time.Time
	BirthWeight *float64
	BirthLength *float64
	BirthPlace  *string
	Timezone    string
}

// UpdateBabyInput holds optional fields for updating a baby profile.
type UpdateBabyInput struct {
	Name        *string
	FullName    *string
	Gender      *model.BabyGender
	BirthDate   *time.Time
	BirthTime   *time.Time
	BirthWeight *float64
	BirthLength *float64
	BirthPlace  *string
	Timezone    *string
	AvatarURL   *string
}

// BabyStore persists baby profiles.
type BabyStore interface {
	CreateBaby(ctx context.Context, in CreateBabyInput) (*model.Baby, error)
	ListBabiesByFamily(ctx context.Context, familyID string) ([]model.Baby, error)
	GetBaby(ctx context.Context, babyID string) (*model.Baby, error)
	UpdateBaby(ctx context.Context, babyID string, in UpdateBabyInput) (*model.Baby, error)
	SoftDeleteBaby(ctx context.Context, babyID string) error
}

// AccountStore manages account deletion and data export requests.
type AccountStore interface {
	FindUserIncludingDeleted(ctx context.Context, userID string) (*model.User, error)
	SoftDeleteUser(ctx context.Context, userID string, deletedAt time.Time) error
	RestoreUser(ctx context.Context, userID string) error
	GetDeletion(ctx context.Context, userID string) (*model.AccountDeletion, error)
	UpsertDeletion(ctx context.Context, userID string, requestedAt, scheduledAt time.Time) (*model.AccountDeletion, error)
	CancelDeletion(ctx context.Context, userID string, cancelledAt time.Time) (*model.AccountDeletion, error)
	ListDueDeletions(ctx context.Context, before time.Time) ([]model.AccountDeletion, error)
	CompleteHardDeletion(ctx context.Context, userID string, completedAt time.Time) error
	CreateExportRequest(ctx context.Context, userID, exportID string, requestedAt time.Time) (*model.DataExportRequest, error)
	GetPendingExport(ctx context.Context, userID string) (*model.DataExportRequest, error)
}

// UpsertBackupProviderInput holds fields for binding or refreshing a backup provider.
type UpsertBackupProviderInput struct {
	ID                string
	UserID            string
	Kind              string
	AccessToken       string
	RefreshToken      *string
	ExpiresAt         *time.Time
	ProviderAccountID *string
	Metadata          map[string]string
	Status            model.BackupProviderStatus
	Now               time.Time
}

// UpsertBackupStatusInput holds fields for reporting backup outcomes.
type UpsertBackupStatusInput struct {
	UserID      string
	Success     bool
	AttemptedAt time.Time
	ErrorCode   *string
	Now         time.Time
}

// BackupStore persists backup provider credentials and status metadata.
type BackupStore interface {
	UpsertBackupProvider(ctx context.Context, in UpsertBackupProviderInput) (*model.BackupProvider, error)
	ListBackupProviders(ctx context.Context, userID string) ([]model.BackupProvider, error)
	DeleteBackupProvider(ctx context.Context, userID, providerID string) error
	GetBackupStatus(ctx context.Context, userID string) (*model.BackupStatus, error)
	UpsertBackupStatus(ctx context.Context, in UpsertBackupStatusInput) (*model.BackupStatus, error)
}

// Store combines user, family, baby, consent, account, and backup persistence.
type Store interface {
	UserStore
	FamilyStore
	BabyStore
	ConsentStore
	AccountStore
	BackupStore
	Ping(ctx context.Context) error
}
