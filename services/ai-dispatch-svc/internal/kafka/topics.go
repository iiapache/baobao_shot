package kafka

// Internal worker queue topics (infra/messaging/kafka/topics.yaml internalTopics).
const (
	TopicImage = "ai.image"
	TopicVideo = "ai.video"
)

// TaskMessage is the payload enqueued for worker consumption.
type TaskMessage struct {
	TaskID     string `json:"taskId"`
	UserID     string `json:"userId"`
	Capability string `json:"capability"`
	Style      string `json:"style"`
	Region     string `json:"region"`
}

// TopicForCapability maps task capability to the correct internal topic.
func TopicForCapability(capability string) string {
	switch capability {
	case "video-gen":
		return TopicVideo
	default:
		return TopicImage
	}
}
