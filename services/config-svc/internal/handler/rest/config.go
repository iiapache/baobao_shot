package rest

import (
	"net/http"
	"strings"

	"github.com/baobao/config-svc/internal/feature"
	"github.com/baobao/config-svc/internal/middleware"
	"github.com/baobao/config-svc/internal/store"
	"github.com/google/uuid"
)

const featuresTTLSeconds = 300

// ConfigHandler serves feature flags and play catalog endpoints.
type ConfigHandler struct {
	store store.Store
}

// NewConfigHandler creates handlers backed by the given store.
func NewConfigHandler(s store.Store) *ConfigHandler {
	return &ConfigHandler{store: s}
}

type apiResponse struct {
	Code      string `json:"code"`
	Message   string `json:"message,omitempty"`
	RequestID string `json:"requestId"`
	Data      any    `json:"data,omitempty"`
}

type featuresData struct {
	Version    string                       `json:"version"`
	TTLSeconds int                          `json:"ttlSeconds"`
	Context    featureEvalContext           `json:"context"`
	Features   map[string]feature.Result    `json:"features"`
}

type featureEvalContext struct {
	Region     string `json:"region"`
	AppVersion string `json:"appVersion,omitempty"`
	UserIDHash int    `json:"userIdHash"`
}

type playsData struct {
	Version string                 `json:"version"`
	Plays   []store.PlayDefinition `json:"plays"`
	Source  string                 `json:"source"`
}

// Features handles GET /v1/config/features.
func (h *ConfigHandler) Features(w http.ResponseWriter, r *http.Request) {
	region, ok := middleware.RegionFromContext(r.Context())
	if !ok || (region != "cn" && region != "os") {
		writeJSON(w, http.StatusBadRequest, apiResponse{
			Code:      "COMMON_BAD_PARAM",
			Message:   "X-Region header required (cn|os)",
			RequestID: requestID(r),
		})
		return
	}

	appVersion, _ := middleware.AppVersionFromContext(r.Context())
	userID, _ := middleware.UserIDFromContext(r.Context())

	evalCtx := feature.EvalContext{
		Region:     region,
		AppVersion: appVersion,
		UserID:     userID,
	}
	if hash, ok := middleware.UserIDHashFromContext(r.Context()); ok {
		evalCtx.UserIDHash = hash
	} else if userID != "" {
		evalCtx.UserIDHash = feature.UserIDHash(userID)
	}

	snapshot := h.store.GetSnapshot()
	results := make(map[string]feature.Result, len(snapshot.Features))
	for _, def := range snapshot.Features {
		result := feature.Evaluate(def, evalCtx)
		if strings.HasPrefix(def.Key, "rollout.") {
			pct := def.RolloutPercent
			result.RolloutPercent = &pct
		}
		results[def.Key] = result
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		RequestID: requestID(r),
		Data: featuresData{
			Version:    snapshot.Version,
			TTLSeconds: featuresTTLSeconds,
			Context: featureEvalContext{
				Region:     region,
				AppVersion: appVersion,
				UserIDHash: evalCtx.UserIDHash,
			},
			Features: results,
		},
	})
}

// Plays handles GET /v1/config/plays.
func (h *ConfigHandler) Plays(w http.ResponseWriter, r *http.Request) {
	region, _ := middleware.RegionFromContext(r.Context())
	snapshot := h.store.GetSnapshot()

	plays := make([]store.PlayDefinition, 0, len(snapshot.Plays))
	for _, play := range snapshot.Plays {
		if len(play.Regions) == 0 || region == "" {
			plays = append(plays, play)
			continue
		}
		for _, allowed := range play.Regions {
			if allowed == region {
				plays = append(plays, play)
				break
			}
		}
	}

	writeJSON(w, http.StatusOK, apiResponse{
		Code:      "OK",
		RequestID: requestID(r),
		Data: playsData{
			Version: snapshot.Version,
			Plays:   plays,
			Source:  "config-svc",
		},
	})
}

func requestID(r *http.Request) string {
	if id := r.Header.Get("X-Request-Id"); id != "" {
		return id
	}
	return "req_" + uuid.New().String()[:8]
}
