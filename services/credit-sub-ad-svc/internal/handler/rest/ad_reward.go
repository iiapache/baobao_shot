package rest

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/adreward"
	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
)

// AdRewardHandler serves ad reward client report and alliance callbacks.
type AdRewardHandler struct {
	svc *adreward.Service
}

// NewAdRewardHandler creates ad reward REST handlers.
func NewAdRewardHandler(svc *adreward.Service) *AdRewardHandler {
	return &AdRewardHandler{svc: svc}
}

type clientAdRewardRequest struct {
	Network     string `json:"network"`
	PlacementID string `json:"placementId"`
	TransID     string `json:"transId"`
	IDFV        string `json:"idfv"`
}

type alliancePangleRequest struct {
	UserID  string `json:"user_id"`
	TransID string `json:"trans_id"`
	Sign    string `json:"sign"`
	Extra   string `json:"extra"`
}

type allianceGDTRequest struct {
	UserID  string `json:"userid"`
	TransID string `json:"transid"`
	Sign    string `json:"sig"`
}

type adRewardResponseData struct {
	GrantedCredits int64  `json:"grantedCredits"`
	BalanceAfter   int64  `json:"balanceAfter"`
	LedgerID       string `json:"ledgerId"`
	Duplicate      bool   `json:"duplicate,omitempty"`
}

// ClientReport handles POST /v1/credits/ad-reward.
func (h *AdRewardHandler) ClientReport(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "ad reward service unavailable", r)
		return
	}

	var req clientAdRewardRequest
	if err := decodeJSONBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return
	}

	timestampMs, err := parseTimestampHeader(r.Header.Get("X-Timestamp"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid X-Timestamp", r)
		return
	}

	result, err := h.svc.ClientReport(r.Context(), adreward.ClientRequest{
		UserID:      userID,
		Network:     adreward.NormalizeNetwork(req.Network),
		PlacementID: req.PlacementID,
		TransID:     req.TransID,
		IDFV:        req.IDFV,
		Nonce:       r.Header.Get("X-Nonce"),
		TimestampMs: timestampMs,
	})
	if err != nil {
		writeAdRewardError(w, r, err)
		return
	}
	writeAdRewardSuccess(w, r, result)
}

// PangleCallback handles POST /v1/credits/ad-reward/pangle/callback.
func (h *AdRewardHandler) PangleCallback(w http.ResponseWriter, r *http.Request) {
	h.allianceJSONCallback(w, r, adreward.NetworkPangle, func(body []byte) (adreward.AllianceRequest, error) {
		var req alliancePangleRequest
		if err := json.Unmarshal(body, &req); err != nil {
			return adreward.AllianceRequest{}, err
		}
		return adreward.AllianceRequest{
			Network:     adreward.NetworkPangle,
			UserID:      req.UserID,
			PlacementID: "pangle",
			TransID:     req.TransID,
			Sign:        req.Sign,
		}, nil
	})
}

// GDTCallback handles POST /v1/credits/ad-reward/gdt/callback.
func (h *AdRewardHandler) GDTCallback(w http.ResponseWriter, r *http.Request) {
	h.allianceJSONCallback(w, r, adreward.NetworkGDT, func(body []byte) (adreward.AllianceRequest, error) {
		var req allianceGDTRequest
		if err := json.Unmarshal(body, &req); err != nil {
			return adreward.AllianceRequest{}, err
		}
		return adreward.AllianceRequest{
			Network:     adreward.NetworkGDT,
			UserID:      req.UserID,
			PlacementID: "gdt",
			TransID:     req.TransID,
			Sign:        req.Sign,
		}, nil
	})
}

// AdMobCallback handles GET/POST /v1/credits/ad-reward/admob/callback.
func (h *AdRewardHandler) AdMobCallback(w http.ResponseWriter, r *http.Request) {
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "ad reward service unavailable", r)
		return
	}
	q := r.URL.Query()
	req := adreward.AllianceRequest{
		Network:     adreward.NetworkAdMob,
		UserID:      q.Get("user_id"),
		PlacementID: q.Get("ad_unit"),
		TransID:     q.Get("transaction_id"),
		Sign:        q.Get("signature"),
	}
	if req.TransID == "" {
		req.TransID = q.Get("trans_id")
	}
	if req.UserID == "" {
		req.UserID = q.Get("custom_data")
	}
	if req.PlacementID == "" {
		req.PlacementID = "admob"
	}

	result, err := h.svc.AllianceCallback(r.Context(), req)
	if err != nil {
		writeAdRewardError(w, r, err)
		return
	}
	writeAdRewardSuccess(w, r, result)
}

func (h *AdRewardHandler) allianceJSONCallback(
	w http.ResponseWriter,
	r *http.Request,
	network string,
	parse func([]byte) (adreward.AllianceRequest, error),
) {
	if h.svc == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "ad reward service unavailable", r)
		return
	}
	body, err := readBody(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid body", r)
		return
	}
	req, err := parse(body)
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return
	}
	if req.Network == "" {
		req.Network = network
	}
	result, err := h.svc.AllianceCallback(r.Context(), req)
	if err != nil {
		writeAdRewardError(w, r, err)
		return
	}
	writeAdRewardSuccess(w, r, result)
}

func writeAdRewardSuccess(w http.ResponseWriter, r *http.Request, result adreward.Result) {
	writeAPI(w, http.StatusOK, "OK", "", r, adRewardResponseData{
		GrantedCredits: result.GrantedCredits,
		BalanceAfter:   result.BalanceAfter,
		LedgerID:       result.LedgerID,
		Duplicate:      result.Duplicate,
	})
}

func writeAdRewardError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, adreward.ErrInvalidRequest):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid ad reward request", r)
	case errors.Is(err, adreward.ErrInvalidSignature):
		writeError(w, http.StatusForbidden, "CREDIT_AD_SIGNATURE_INVALID", "invalid alliance signature", r)
	case errors.Is(err, adreward.ErrDailyLimit):
		writeError(w, http.StatusTooManyRequests, "CREDIT_AD_DAILY_LIMIT", "daily ad reward limit exceeded", r)
	case errors.Is(err, adreward.ErrFrequencyLimit):
		writeError(w, http.StatusTooManyRequests, "CREDIT_AD_FREQUENCY_LIMIT", "ad reward too frequent", r)
	case errors.Is(err, adreward.ErrReplay):
		writeError(w, http.StatusConflict, "COMMON_REPLAY", "replay detected", r)
	default:
		writeError(w, http.StatusInternalServerError, "SYS_INTERNAL", "ad reward failed", r)
	}
}

func decodeJSONBody(r *http.Request, dst any) error {
	body, err := readBody(r)
	if err != nil {
		return err
	}
	return json.Unmarshal(body, dst)
}

func readBody(r *http.Request) ([]byte, error) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if len(strings.TrimSpace(string(body))) == 0 {
		return nil, errors.New("empty body")
	}
	return body, nil
}

func parseTimestampHeader(raw string) (int64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, errors.New("missing timestamp")
	}
	return strconv.ParseInt(raw, 10, 64)
}
