package wspush

const (
	OpSubscribe = "subscribe"
	OpEvent     = "event"
	OpPing      = "ping"
	OpPong      = "pong"
	OpError     = "error"
)

// ClientMessage is a message from the WebSocket client.
type ClientMessage struct {
	Op        string   `json:"op"`
	FamilyIDs []string `json:"familyIds,omitempty"`
}

// ServerMessage is a message sent to the WebSocket client.
type ServerMessage struct {
	Op        string `json:"op"`
	Kind      string `json:"kind,omitempty"`
	FamilyID  string `json:"familyId,omitempty"`
	PostID    string `json:"postId,omitempty"`
	UserID    string `json:"userId,omitempty"`
	CommentID string `json:"commentId,omitempty"`
	Text      string `json:"text,omitempty"`
	LikedAt   string `json:"likedAt,omitempty"`
	CreatedAt string `json:"createdAt,omitempty"`
	Code      string `json:"code,omitempty"`
	Message   string `json:"message,omitempty"`
}
