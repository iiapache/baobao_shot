package auth

import "strings"

// ParseDevToken resolves local dev placeholder tokens to a user id.
func ParseDevToken(token string) string {
	if token == "" || token == "invalid" {
		return ""
	}
	if token == "dev" {
		return "usr_dev"
	}
	if strings.HasPrefix(token, "dev:") {
		return strings.TrimPrefix(token, "dev:")
	}
	if strings.HasPrefix(token, "atk_") {
		body := strings.TrimPrefix(token, "atk_")
		if idx := strings.LastIndex(body, "_"); idx > 0 {
			return body[:idx]
		}
	}
	return ""
}
