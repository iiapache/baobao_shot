package kafka

const (
	TopicAIEvents    = "ai.events"
	TopicFeedEvents  = "feed.events"
	TopicCreditEvents = "credit.events"
)

// ConsumerTopics lists Kafka topics consumed by notification-svc (T5.9).
var ConsumerTopics = []string{
	TopicAIEvents,
	TopicFeedEvents,
	TopicCreditEvents,
}
