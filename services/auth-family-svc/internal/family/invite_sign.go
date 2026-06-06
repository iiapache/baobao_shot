package family

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
)

// QRPayload is the signed JSON embedded in invitation QR codes.
type QRPayload struct {
	Scheme string `json:"scheme"`
	Code   string `json:"code"`
	Sig    string `json:"sig"`
}

// SignInvitePayload builds a signed QR payload for the given invite code.
func SignInvitePayload(appScheme, code, signingSecret string) QRPayload {
	return QRPayload{
		Scheme: appScheme,
		Code:   code,
		Sig:    signInviteCode(code, signingSecret),
	}
}

// VerifyInvitePayload checks the HMAC signature on a QR payload.
func VerifyInvitePayload(payload QRPayload, signingSecret string) bool {
	expected := signInviteCode(payload.Code, signingSecret)
	return hmac.Equal([]byte(expected), []byte(payload.Sig))
}

func signInviteCode(code, signingSecret string) string {
	mac := hmac.New(sha256.New, []byte(signingSecret))
	_, _ = mac.Write([]byte(code))
	return hex.EncodeToString(mac.Sum(nil))
}

// MarshalQRPayload serializes the payload to JSON bytes.
func MarshalQRPayload(payload QRPayload) ([]byte, error) {
	return json.Marshal(payload)
}

// GenerateInviteCode returns a random 6-digit numeric code.
func GenerateInviteCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", fmt.Errorf("generate invite code: %w", err)
	}
	return fmt.Sprintf("%06d", n.Int64()+100000), nil
}
