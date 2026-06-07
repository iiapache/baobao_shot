package kafka

import (
	"context"
	"testing"

	"github.com/baobao/credit-sub-ad-svc/internal/config"
)

func TestConsumerStartDisabled(t *testing.T) {
	consumer := NewConsumer(&config.Config{}, nil)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := consumer.Start(ctx); err != nil {
		t.Fatalf("Start() error = %v", err)
	}
}
