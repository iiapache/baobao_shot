package iap

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"
)

// JWSVerifier validates StoreKit 2 signed transactions.
// Production should verify ES256 signatures against Apple root certificates;
// this implementation parses the payload and enforces structural checks for sandbox/dev.
type JWSVerifier struct {
	AllowedBundleIDs map[string]struct{}
}

// NewJWSVerifier creates a verifier with optional bundle allowlist.
func NewJWSVerifier(bundleIDs ...string) *JWSVerifier {
	allowed := make(map[string]struct{}, len(bundleIDs))
	for _, id := range bundleIDs {
		id = strings.TrimSpace(id)
		if id != "" {
			allowed[id] = struct{}{}
		}
	}
	return &JWSVerifier{AllowedBundleIDs: allowed}
}

type jwsPayload struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
	BundleID              string `json:"bundleId"`
	PurchaseDate          int64  `json:"purchaseDate"`
	ExpiresDate           int64  `json:"expiresDate"`
	OfferType             int    `json:"offerType"`
	AutoRenewStatus       int    `json:"autoRenewStatus"`
}

// Verify parses and validates a StoreKit 2 JWS (signature verification stubbed).
func (v *JWSVerifier) Verify(_ context.Context, signedTransaction string) (*VerifiedTransaction, error) {
	signedTransaction = strings.TrimSpace(signedTransaction)
	if signedTransaction == "" {
		return nil, ErrVerifyFailed
	}

	if strings.HasPrefix(signedTransaction, "mock:") {
		return parseMockJWS(signedTransaction)
	}

	payload, err := decodeJWSPayload(signedTransaction)
	if err != nil {
		return nil, err
	}
	if payload.TransactionID == "" || payload.ProductID == "" {
		return nil, ErrVerifyFailed
	}
	if payload.OriginalTransactionID == "" {
		payload.OriginalTransactionID = payload.TransactionID
	}
	if len(v.AllowedBundleIDs) > 0 {
		if _, ok := v.AllowedBundleIDs[payload.BundleID]; !ok {
			return nil, ErrVerifyFailed
		}
	}
	return verifiedFromPayload(*payload), nil
}

func parseMockJWS(raw string) (*VerifiedTransaction, error) {
	// mock:transactionId:productId[:originalTransactionId[:bundleId[:purchaseMs[:expiresMs[:trial[:autoRenew]]]]]]]
	parts := strings.Split(strings.TrimPrefix(raw, "mock:"), ":")
	if len(parts) < 2 {
		return nil, ErrVerifyFailed
	}
	tx := strings.TrimSpace(parts[0])
	productID := strings.TrimSpace(parts[1])
	if tx == "" || productID == "" {
		return nil, ErrVerifyFailed
	}
	originalTx := tx
	if len(parts) >= 3 && strings.TrimSpace(parts[2]) != "" {
		originalTx = strings.TrimSpace(parts[2])
	}
	bundleID := ""
	if len(parts) >= 4 {
		bundleID = strings.TrimSpace(parts[3])
	}

	payload := jwsPayload{
		TransactionID:         tx,
		OriginalTransactionID: originalTx,
		ProductID:             productID,
		BundleID:              bundleID,
		AutoRenewStatus:       1,
	}
	if len(parts) >= 5 {
		payload.PurchaseDate = parseMockMillis(parts[4])
	}
	if len(parts) >= 6 {
		payload.ExpiresDate = parseMockMillis(parts[5])
	}
	if len(parts) >= 7 {
		payload.OfferType = parseMockInt(parts[6])
	}
	if len(parts) >= 8 {
		payload.AutoRenewStatus = parseMockInt(parts[7])
	}
	return verifiedFromPayload(payload), nil
}

func verifiedFromPayload(payload jwsPayload) *VerifiedTransaction {
	if payload.OriginalTransactionID == "" {
		payload.OriginalTransactionID = payload.TransactionID
	}
	return &VerifiedTransaction{
		TransactionID:         payload.TransactionID,
		OriginalTransactionID: payload.OriginalTransactionID,
		ProductID:             payload.ProductID,
		BundleID:              payload.BundleID,
		PurchaseDate:          millisToTime(payload.PurchaseDate),
		ExpiresDate:           millisToTime(payload.ExpiresDate),
		IsTrial:               payload.OfferType == 1,
		AutoRenewEnabled:      payload.AutoRenewStatus == 1,
	}
}

func millisToTime(ms int64) time.Time {
	if ms <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}

func parseMockMillis(raw string) int64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	v, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return 0
	}
	return v
}

func parseMockInt(raw string) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return 0
	}
	return v
}

func decodeJWSPayload(token string) (*jwsPayload, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrVerifyFailed
	}
	if strings.TrimSpace(parts[0]) == "" || strings.TrimSpace(parts[2]) == "" {
		return nil, ErrVerifyFailed
	}

	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, errors.Join(ErrVerifyFailed, err)
	}
	var payload jwsPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, errors.Join(ErrVerifyFailed, err)
	}
	return &payload, nil
}
