package middleware

import (
	"context"
	"net/http"
	"strconv"
	"strings"
)

type contextKey string

const (
	regionKey     contextKey = "region"
	appVersionKey contextKey = "appVersion"
	deviceIDKey   contextKey = "deviceId"
	userIDHashKey contextKey = "userIdHash"
)

// RequestContext extracts gray-release dimensions from gateway-forwarded headers.
func RequestContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if region := strings.ToLower(strings.TrimSpace(r.Header.Get("X-Region"))); region != "" {
			ctx = context.WithValue(ctx, regionKey, region)
		}
		if appVersion := strings.TrimSpace(r.Header.Get("X-App-Version")); appVersion != "" {
			ctx = context.WithValue(ctx, appVersionKey, appVersion)
		}
		if deviceID := strings.TrimSpace(r.Header.Get("X-Device-Id")); deviceID != "" {
			ctx = context.WithValue(ctx, deviceIDKey, deviceID)
		}
		if raw := strings.TrimSpace(r.Header.Get("X-User-Id-Hash")); raw != "" {
			if n, err := strconv.Atoi(raw); err == nil && n >= 0 && n < 100 {
				ctx = context.WithValue(ctx, userIDHashKey, n)
			}
		}

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// RegionFromContext returns the request region (cn/os).
func RegionFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(regionKey).(string)
	return v, ok
}

// AppVersionFromContext returns the client app version header.
func AppVersionFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(appVersionKey).(string)
	return v, ok
}

// DeviceIDFromContext returns the device id header.
func DeviceIDFromContext(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(deviceIDKey).(string)
	return v, ok
}

// UserIDHashFromContext returns an optional precomputed hash from the client.
func UserIDHashFromContext(ctx context.Context) (int, bool) {
	v, ok := ctx.Value(userIDHashKey).(int)
	return v, ok
}
