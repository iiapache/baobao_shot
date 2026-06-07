package kafka

import (
	"context"
	"testing"
)

func TestTopicForCapability(t *testing.T) {
	if TopicForCapability("video-gen") != TopicVideo {
		t.Fatal("video-gen should map to ai.video")
	}
	if TopicForCapability("image-gen") != TopicImage {
		t.Fatal("image-gen should map to ai.image")
	}
	if TopicForCapability("image-edit") != TopicImage {
		t.Fatal("image-edit should map to ai.image")
	}
}

func TestStubProducerConsumer(t *testing.T) {
	producer := NewStubProducer()
	consumer := NewStubConsumer()

	received := make(chan TaskMessage, 1)
	if err := consumer.Subscribe([]string{TopicImage, TopicVideo}, func(_ context.Context, topic string, msg TaskMessage) error {
		received <- msg
		if topic != TopicImage {
			t.Errorf("topic = %s, want %s", topic, TopicImage)
		}
		return nil
	}); err != nil {
		t.Fatalf("Subscribe() error = %v", err)
	}

	msg := TaskMessage{TaskID: "tsk_test", UserID: "usr_test", Capability: "image-gen", Style: "ghibli_kid", Region: "cn"}
	if err := producer.Publish(context.Background(), TopicImage, msg); err != nil {
		t.Fatalf("Publish() error = %v", err)
	}

	payload, err := Encode(msg)
	if err != nil {
		t.Fatalf("Encode() error = %v", err)
	}
	if err := consumer.Inject(context.Background(), TopicImage, payload); err != nil {
		t.Fatalf("Inject() error = %v", err)
	}

	got := <-received
	if got.TaskID != msg.TaskID {
		t.Fatalf("TaskID = %s, want %s", got.TaskID, msg.TaskID)
	}
	if len(producer.Messages(TopicImage)) != 1 {
		t.Fatal("producer should record one message")
	}
}
