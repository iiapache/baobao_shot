package worker

import (
	"context"
	"log/slog"
	"sync"

	"github.com/baobao/ai-dispatch-svc/internal/kafka"
)

// Pool is a bounded worker pool consuming Kafka task messages.
type Pool struct {
	size      int
	processor *Processor
	jobs      chan kafkaJob
	wg        sync.WaitGroup
}

type kafkaJob struct {
	topic string
	msg   kafka.TaskMessage
}

// NewPool creates a worker pool with the given concurrency.
func NewPool(size int, processor *Processor) *Pool {
	if size < 1 {
		size = 1
	}
	return &Pool{
		size:      size,
		processor: processor,
		jobs:      make(chan kafkaJob, size*2),
	}
}

// Start launches worker goroutines until ctx is cancelled.
func (p *Pool) Start(ctx context.Context) {
	for i := 0; i < p.size; i++ {
		p.wg.Add(1)
		go func(workerID int) {
			defer p.wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case job, ok := <-p.jobs:
					if !ok {
						return
					}
					if err := p.processor.Process(ctx, job.msg); err != nil {
						slog.Error("worker process failed",
							"worker", workerID,
							"topic", job.topic,
							"taskId", job.msg.TaskID,
							"error", err,
						)
					}
				}
			}
		}(i)
	}
}

// Submit enqueues a Kafka message for worker processing.
func (p *Pool) Submit(ctx context.Context, topic string, msg kafka.TaskMessage) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case p.jobs <- kafkaJob{topic: topic, msg: msg}:
		return nil
	}
}

// Stop closes the job queue and waits for workers to drain in-flight jobs.
func (p *Pool) Stop() {
	close(p.jobs)
	p.wg.Wait()
}

// Size returns configured worker concurrency.
func (p *Pool) Size() int {
	return p.size
}
