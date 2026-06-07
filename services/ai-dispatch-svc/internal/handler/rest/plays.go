package rest

import (
	"encoding/json"
	"net/http"

	"github.com/baobao/ai-dispatch-svc/internal/middleware"
	"github.com/baobao/ai-dispatch-svc/internal/plays"
	"github.com/google/uuid"
)

// PlaysHandler serves GET /v1/ai/plays.
type PlaysHandler struct {
	catalog *plays.Catalog
}

// NewPlaysHandler creates play catalog REST handlers.
func NewPlaysHandler(catalog *plays.Catalog) *PlaysHandler {
	return &PlaysHandler{catalog: catalog}
}

// List handles GET /v1/ai/plays (operationId: aiListPlays).
func (h *PlaysHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "authentication required", r)
		return
	}

	region, ok := middleware.RegionFromContext(r.Context())
	if !ok || (region != "cn" && region != "os") {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "region required (cn|os)", r)
		return
	}

	appVersion, _ := middleware.AppVersionFromContext(r.Context())

	data, err := h.catalog.List(r.Context(), plays.ListOptions{
		Region:     region,
		AppVersion: appVersion,
		UserID:     userID,
	})
	if err != nil {
		writeError(w, http.StatusBadGateway, "COMMON_UPSTREAM", "config service unavailable", r)
		return
	}

	writeAPI(w, http.StatusOK, "OK", "", r, data)
}

type apiResponse struct {
	Code      string `json:"code"`
	Message   string `json:"message,omitempty"`
	RequestID string `json:"requestId"`
	Data      any    `json:"data,omitempty"`
}

func requestID(r *http.Request) string {
	if id := r.Header.Get("X-Request-Id"); id != "" {
		return id
	}
	if id := r.Header.Get("X-Trace-Id"); id != "" {
		return id
	}
	return "req_" + uuid.NewString()[:8]
}

func writeAPI(w http.ResponseWriter, status int, code, message string, r *http.Request, data ...any) {
	resp := apiResponse{
		Code:      code,
		Message:   message,
		RequestID: requestID(r),
	}
	if len(data) > 0 {
		resp.Data = data[0]
	}
	writeJSON(w, status, resp)
}

func writeError(w http.ResponseWriter, status int, code, message string, r *http.Request) {
	writeAPI(w, status, code, message, r)
}

func decodeAPIResponse(body []byte) (apiResponse, error) {
	var resp apiResponse
	err := json.Unmarshal(body, &resp)
	return resp, err
}
