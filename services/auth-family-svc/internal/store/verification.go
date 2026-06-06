package store

import (
	"context"
	"errors"
	"time"
)

var (
	// ErrVerificationNotFound is returned when no active verification code exists.
	ErrVerificationNotFound = errors.New("verification code not found")
	// ErrVerificationMismatch is returned when the submitted code does not match.
	ErrVerificationMismatch = errors.New("verification code mismatch")
	// ErrVerificationExpired is returned when the code TTL has elapsed.
	ErrVerificationExpired = errors.New("verification code expired")
)

// VerificationRecord holds a persisted SMS verification code.
type VerificationRecord struct {
	Phone     string
	Region    string
	Code      string
	CreatedAt time.Time
	ExpiresAt time.Time
}

// VerificationStore persists phone verification codes.
type VerificationStore interface {
	SaveCode(ctx context.Context, phone, region, code string, sentAt, expiresAt time.Time) error
	VerifyAndConsume(ctx context.Context, phone, region, code string, now time.Time) error
	LastSentAt(ctx context.Context, phone, region string) (time.Time, bool, error)
}
