package ws

import "github.com/baobao/ai-dispatch-svc/internal/model"

const (
	OpSubscribe = "subscribe"
	OpEvent     = "event"
	OpPing      = "ping"
	OpPong      = "pong"
	OpError     = "error"
)

// ClientMessage is a message from the WebSocket client.
type ClientMessage struct {
	Op      string   `json:"op"`
	TaskIDs []string `json:"taskIds,omitempty"`
}

// ServerMessage is a message sent to the WebSocket client.
type ServerMessage struct {
	Op           string                   `json:"op"`
	TaskID       string                   `json:"taskId,omitempty"`
	State        string                   `json:"state,omitempty"`
	ResultURL    string                   `json:"resultUrl,omitempty"`
	ThumbnailURL string                   `json:"thumbnailUrl,omitempty"`
	DeepSynth    *model.DeepSynthMetadata `json:"deepSynth,omitempty"`
	CostCredits  int                      `json:"costCredits,omitempty"`
	BalanceAfter int                      `json:"balanceAfter,omitempty"`
	Code         string                   `json:"code,omitempty"`
	Message      string                   `json:"message,omitempty"`
}

// TaskEvent is the payload broadcast to subscribed clients.
type TaskEvent struct {
	TaskID       string
	State        string
	ResultURL    string
	ThumbnailURL string
	DeepSynth    *model.DeepSynthMetadata
	CostCredits  int
	BalanceAfter int
}
