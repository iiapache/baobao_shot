package rest

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
)

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
