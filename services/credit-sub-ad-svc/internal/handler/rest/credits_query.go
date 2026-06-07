package rest

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/middleware"
	"github.com/baobao/credit-sub-ad-svc/internal/query"
)

const (
	defaultPageLimit = 20
	maxPageLimit     = 50
)

// CreditsQueryHandler serves read-only credit APIs.
type CreditsQueryHandler struct {
	query *query.Service
}

// NewCreditsQueryHandler creates credit query REST handlers.
func NewCreditsQueryHandler(svc *query.Service) *CreditsQueryHandler {
	return &CreditsQueryHandler{query: svc}
}

// GetBalance handles GET /v1/credits/balance (operationId: creditsGetBalance).
func (h *CreditsQueryHandler) GetBalance(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	if h.query == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "query service unavailable", r)
		return
	}

	data, err := h.query.GetBalance(r.Context(), userID)
	if err != nil {
		writeQueryError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

// ListTransactions handles GET /v1/credits/transactions (operationId: creditsListTransactions).
func (h *CreditsQueryHandler) ListTransactions(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	if h.query == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "query service unavailable", r)
		return
	}

	limit, err := parsePageLimit(r.URL.Query().Get("limit"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid limit", r)
		return
	}

	data, err := h.query.ListTransactions(r.Context(), query.ListTransactionsInput{
		UserID: userID,
		Cursor: r.URL.Query().Get("cursor"),
		Limit:  limit,
	})
	if err != nil {
		writeQueryError(w, r, err)
		return
	}
	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

// GetRates handles GET /v1/credits/rates (operationId: creditsGetRates).
func (h *CreditsQueryHandler) GetRates(w http.ResponseWriter, r *http.Request) {
	if _, ok := requireUser(w, r); !ok {
		return
	}
	if h.query == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "query service unavailable", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, h.query.GetRates(r.Context()))
}

// SubscriptionsQueryHandler serves read-only subscription APIs.
type SubscriptionsQueryHandler struct {
	query *query.Service
}

// NewSubscriptionsQueryHandler creates subscription query REST handlers.
func NewSubscriptionsQueryHandler(svc *query.Service) *SubscriptionsQueryHandler {
	return &SubscriptionsQueryHandler{query: svc}
}

// ListProducts handles GET /v1/subscriptions/products (operationId: subscriptionsListProducts).
func (h *SubscriptionsQueryHandler) ListProducts(w http.ResponseWriter, r *http.Request) {
	if _, ok := requireUser(w, r); !ok {
		return
	}
	if h.query == nil {
		writeError(w, http.StatusServiceUnavailable, "SYS_UPSTREAM_UNAVAILABLE", "query service unavailable", r)
		return
	}

	region, _ := middleware.RegionFromContext(r.Context())
	if region == "" {
		region = r.URL.Query().Get("region")
	}
	writeAPI(w, http.StatusOK, "OK", "", r, h.query.ListSubscriptionProducts(region))
}

func requireUser(w http.ResponseWriter, r *http.Request) (string, bool) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return "", false
	}
	return userID, true
}

func parsePageLimit(raw string) (int, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return defaultPageLimit, nil
	}
	limit, err := strconv.Atoi(raw)
	if err != nil || limit < 1 || limit > maxPageLimit {
		return 0, errors.New("invalid limit")
	}
	return limit, nil
}

func writeQueryError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, query.ErrInvalidRequest):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid request", r)
	case errors.Is(err, query.ErrInvalidCursor):
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid cursor", r)
	default:
		writeError(w, http.StatusInternalServerError, "SYS_INTERNAL", "query failed", r)
	}
}
