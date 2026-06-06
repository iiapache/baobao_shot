package model

import "time"

// Backup provider kinds supported by the platform.
const (
	BackupProviderKindICloud   = "icloud"
	BackupProviderKindBaiduPan = "baidu_pan"
	BackupProviderKindPhotos   = "photos"
)

// BackupProviderStatus describes whether a provider binding is active.
type BackupProviderStatus string

const (
	BackupProviderStatusActive  BackupProviderStatus = "active"
	BackupProviderStatusRevoked BackupProviderStatus = "revoked"
)

// BackupProvider stores OAuth token metadata for a user's backup destination.
// Raw image bytes are never persisted server-side.
type BackupProvider struct {
	ID                string
	UserID            string
	Kind              string
	AccessToken       string
	RefreshToken      *string
	ExpiresAt         *time.Time
	ProviderAccountID *string
	Metadata          map[string]string
	Status            BackupProviderStatus
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

// BackupStatus tracks aggregate backup outcomes reported by the client.
type BackupStatus struct {
	UserID        string
	LastSuccessAt *time.Time
	LastAttemptAt *time.Time
	FailureCount  int
	LastErrorCode *string
	UpdatedAt     time.Time
}
