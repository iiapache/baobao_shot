package kafka

// AI task lifecycle events on ai.events.
const (
	EventAITaskSucceeded = "ai.task.succeeded"
	EventAITaskFailed    = "ai.task.failed"
	EventAITaskRejected  = "ai.task.rejected"
)

// Feed domain events on feed.events.
const (
	EventFeedPostCreated       = "feed.post.created"
	EventFeedPostLiked         = "feed.post.liked"
	EventFeedPostCommented     = "feed.post.commented"
	EventFeedMilestoneReminder = "feed.milestone.reminder"
	EventSystemAnnouncement    = "system.announcement"
)

// Credit ledger events on credit.events.
const (
	EventCreditGranted  = "credit.granted"
	EventCreditRefunded = "credit.refunded"
)

// AIEvent is the ai.events payload envelope.
type AIEvent struct {
	EventType    string `json:"eventType"`
	UserID       string `json:"userId"`
	TaskID       string `json:"taskId"`
	State        string `json:"state"`
	ResultURL    string `json:"resultUrl,omitempty"`
	ThumbnailURL string `json:"thumbnailUrl,omitempty"`
	Reason       string `json:"reason,omitempty"`
}

// FeedEvent is the feed.events payload envelope.
type FeedEvent struct {
	EventType      string `json:"eventType"`
	UserID         string `json:"userId"`
	ActorName      string `json:"actorName,omitempty"`
	PostID         string `json:"postId,omitempty"`
	FamilyID       string `json:"familyId,omitempty"`
	BabyID         string `json:"babyId,omitempty"`
	MilestoneID    string `json:"milestoneId,omitempty"`
	CommentPreview string `json:"commentPreview,omitempty"`
	Title          string `json:"title,omitempty"`
	Body           string `json:"body,omitempty"`
}

// CreditEvent is the credit.events payload envelope.
type CreditEvent struct {
	EventType    string `json:"eventType"`
	UserID       string `json:"userId"`
	Amount       int64  `json:"amount"`
	BalanceAfter int64  `json:"balanceAfter,omitempty"`
	Reason       string `json:"reason,omitempty"`
	TaskID       string `json:"taskId,omitempty"`
}
