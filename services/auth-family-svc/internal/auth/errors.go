package auth

import "errors"

var (
	// ErrInvalidAppleToken indicates Apple identity token verification failed.
	ErrInvalidAppleToken = errors.New("invalid apple identity token")
	// ErrTokenExpired indicates the access token has expired.
	ErrTokenExpired = errors.New("token expired")
	// ErrTokenRevoked indicates the token was revoked (logout or rotation).
	ErrTokenRevoked = errors.New("token revoked")
	// ErrRefreshInvalid indicates the refresh token is invalid or revoked.
	ErrRefreshInvalid = errors.New("refresh token invalid")
	// ErrDeviceMismatch indicates the device id does not match the token binding.
	ErrDeviceMismatch = errors.New("device mismatch")
)
