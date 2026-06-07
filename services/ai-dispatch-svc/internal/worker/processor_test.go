package worker

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/baobao/ai-dispatch-svc/internal/adapter"
	"github.com/baobao/ai-dispatch-svc/internal/costmetering"
	"github.com/baobao/ai-dispatch-svc/internal/kafka"
	"github.com/baobao/ai-dispatch-svc/internal/model"
	"github.com/baobao/ai-dispatch-svc/internal/router"
	"github.com/baobao/ai-dispatch-svc/internal/statemachine"
	"github.com/baobao/ai-dispatch-svc/internal/store"
	"github.com/baobao/ai-dispatch-svc/internal/watermark"
)

func TestInvokeTimeout(t *testing.T) {
	if InvokeTimeout(model.CapabilityImageGen) != 60*time.Second {
		t.Fatalf("image timeout = %v", InvokeTimeout(model.CapabilityImageGen))
	}
	if InvokeTimeout(model.CapabilityVideoGen) != 300*time.Second {
		t.Fatalf("video timeout = %v", InvokeTimeout(model.CapabilityVideoGen))
	}
}

func TestRetryBackoff(t *testing.T) {
	if RetryBackoff(0) != 2*time.Second {
		t.Fatalf("backoff 0 = %v", RetryBackoff(0))
	}
	if RetryBackoff(1) != 5*time.Second {
		t.Fatalf("backoff 1 = %v", RetryBackoff(1))
	}
	if RetryBackoff(9) != 5*time.Second {
		t.Fatalf("backoff cap = %v", RetryBackoff(9))
	}
}

func devFilings() map[string]adapter.FilingInfo {
	return map[string]adapter.FilingInfo{
		"SeedreamAdapter": {GenAIFilingNo: "GAI-DEV-1", DeepSynthFilingNo: "DS-DEV-1"},
	}
}

func seedArtifact(t *testing.T, store watermark.ArtifactStore, objectKey string) {
	t.Helper()
	img := watermark.MinimalPNG(64, 64)
	if err := store.Put(context.Background(), objectKey, img, "image/png"); err != nil {
		t.Fatalf("seed artifact: %v", err)
	}
}

func newTestProcessor(t *testing.T, s store.TaskStore, router *router.ModelRouter, credit *StubCreditClient, artifactKeys ...string) *Processor {
	t.Helper()
	artStore := watermark.NewMemoryArtifactStore()
	for _, key := range artifactKeys {
		seedArtifact(t, artStore, key)
	}
	return NewProcessor(s, router, credit,
		WithArtifactStore(artStore),
		WithFilings(devFilings()),
	)
}

func seedQueuedTask(t *testing.T, s store.TaskStore, id string) *model.Task {
	t.Helper()
	now := time.Now().UTC()
	task := &model.Task{
		ID:           id,
		UserID:       "usr_1",
		Region:       model.RegionCN,
		Style:        "ghibli_kid",
		Capability:   model.CapabilityImageGen,
		Input:        model.TaskInput{ObjectKey: "in/key", SHA256: "abc"},
		State:        string(statemachine.StateQueued),
		StateHistory: []model.StateHistoryEntry{{State: string(statemachine.StateQueued), At: now}},
		CostCredits:  8,
		CreditHoldID: "hold_" + id,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := s.Create(context.Background(), task); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	return task
}

func TestProcessor_RetryableFailureThenSuccess(t *testing.T) {
	var attempts atomic.Int32
	stub := &adapter.StubAdapter{
		AdapterName:   "SeedreamAdapter",
		AdapterRegion: model.RegionCN,
		Capabilities:  []model.Capability{model.CapabilityImageGen},
		InvokeFn: func(ctx context.Context, req adapter.InvokeRequest) (adapter.InvokeOutput, error) {
			n := attempts.Add(1)
			if n < 3 {
				return adapter.InvokeOutput{}, adapter.NewAdapterError(adapter.ErrCodeTransient, "MOCK", "transient")
			}
			return adapter.InvokeOutput{ObjectKey: "out/key", ThumbnailKey: "out/thumb"}, nil
		},
	}

	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_retry_ok")
	credit := NewStubCreditClient()
	var slept []time.Duration
	proc := newTestProcessor(t, s, BuildDevRouter([]adapter.ModelAdapter{stub}, nil), credit, "out/key")
	proc.sleepFn = func(d time.Duration) {
		slept = append(slept, d)
	}

	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: "tsk_retry_ok", UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}

	got, err := s.GetByID(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.State != string(statemachine.StateSucceeded) {
		t.Fatalf("State = %s, want succeeded", got.State)
	}
	if got.DeepSynth.Watermark != watermark.WatermarkVersion || got.DeepSynth.Manifest != watermark.ManifestVersion {
		t.Fatalf("deepSynth = %+v", got.DeepSynth)
	}
	if attempts.Load() != 3 {
		t.Fatalf("attempts = %d, want 3", attempts.Load())
	}
	if got.ModelRetryCount != 2 {
		t.Fatalf("ModelRetryCount = %d, want 2", got.ModelRetryCount)
	}
	if len(got.ModelInvocations) != 3 {
		t.Fatalf("ModelInvocations = %d, want 3", len(got.ModelInvocations))
	}
	if len(slept) != 2 || slept[0] != 2*time.Second || slept[1] != 5*time.Second {
		t.Fatalf("slept = %v, want [2s 5s]", slept)
	}
	if len(credit.Released()) != 0 {
		t.Fatal("credit should not be released on success")
	}
	committed := credit.Committed()
	if len(committed) != 1 {
		t.Fatalf("credit commit = %+v, want 1", committed)
	}
	if committed[0].HoldID != task.CreditHoldID || committed[0].RefKind != RefKindAITaskCommit || committed[0].RefID != task.ID {
		t.Fatalf("commit idempotency = %+v", committed[0])
	}
}

func TestProcessor_RetriesExhaustedCreditRefund(t *testing.T) {
	stub := &adapter.StubAdapter{
		AdapterName:   "SeedreamAdapter",
		AdapterRegion: model.RegionCN,
		Capabilities:  []model.Capability{model.CapabilityImageGen},
		InvokeFn: func(context.Context, adapter.InvokeRequest) (adapter.InvokeOutput, error) {
			return adapter.InvokeOutput{}, adapter.NewAdapterError(adapter.ErrCodeRateLimited, "MOCK", "rate limited")
		},
	}

	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_fail")
	credit := NewStubCreditClient()
	proc := NewProcessor(s, BuildDevRouter([]adapter.ModelAdapter{stub}, nil), credit, WithSleepFn(func(time.Duration) {}))

	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}

	got, _ := s.GetByID(context.Background(), task.ID)
	if got.State != string(statemachine.StateFailed) {
		t.Fatalf("State = %s, want failed", got.State)
	}
	if len(got.ModelInvocations) != 3 {
		t.Fatalf("ModelInvocations = %d, want 3 (initial + 2 retries)", len(got.ModelInvocations))
	}
	released := credit.Released()
	if len(released) != 1 || released[0].HoldID != task.CreditHoldID || released[0].TaskID != task.ID {
		t.Fatalf("credit release = %+v, want hold refund", released)
	}
	if released[0].RefKind != RefKindAITaskRelease || released[0].RefID != task.ID {
		t.Fatalf("release idempotency = %+v, want ref_kind=%s ref_id=%s", released[0], RefKindAITaskRelease, task.ID)
	}
}

func TestProcessor_NonRetryableRejected(t *testing.T) {
	stub := &adapter.StubAdapter{
		AdapterName:   "SeedreamAdapter",
		AdapterRegion: model.RegionCN,
		Capabilities:  []model.Capability{model.CapabilityImageGen},
		InvokeFn: func(context.Context, adapter.InvokeRequest) (adapter.InvokeOutput, error) {
			return adapter.InvokeOutput{}, adapter.NewAdapterError(adapter.ErrCodeContentPolicy, "MOCK", "policy")
		},
	}

	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_reject")
	credit := NewStubCreditClient()
	proc := NewProcessor(s, BuildDevRouter([]adapter.ModelAdapter{stub}, nil), credit)

	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}

	got, _ := s.GetByID(context.Background(), task.ID)
	if got.State != string(statemachine.StateRejected) {
		t.Fatalf("State = %s, want rejected", got.State)
	}
	if len(got.ModelInvocations) != 1 {
		t.Fatalf("ModelInvocations = %d, want 1", len(got.ModelInvocations))
	}
	if len(credit.Released()) != 1 {
		t.Fatal("expected credit refund on rejected")
	}
}

func TestProcessor_ImageInvokeTimeout(t *testing.T) {
	stub := &adapter.StubAdapter{
		AdapterName:   "SeedreamAdapter",
		AdapterRegion: model.RegionCN,
		Capabilities:  []model.Capability{model.CapabilityImageGen},
		InvokeFn: func(ctx context.Context, req adapter.InvokeRequest) (adapter.InvokeOutput, error) {
			select {
			case <-ctx.Done():
				return adapter.InvokeOutput{}, ctx.Err()
			case <-time.After(200 * time.Millisecond):
				return adapter.InvokeOutput{ObjectKey: "late"}, nil
			}
		},
	}

	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_timeout")
	credit := NewStubCreditClient()
	proc := NewProcessor(s, BuildDevRouter([]adapter.ModelAdapter{stub}, nil), credit,
		WithSleepFn(func(time.Duration) {}),
		WithInvokeTimeout(func(model.Capability) time.Duration { return 50 * time.Millisecond }),
	)

	start := time.Now()
	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}
	if elapsed := time.Since(start); elapsed > 2*time.Second {
		t.Fatalf("elapsed = %v, expected bounded by short test timeouts", elapsed)
	}

	got, _ := s.GetByID(context.Background(), task.ID)
	if got.State != string(statemachine.StateFailed) {
		t.Fatalf("State = %s, want failed after timeout retries", got.State)
	}
	if len(credit.Released()) != 1 {
		t.Fatal("expected credit refund after exhausted timeout retries")
	}
}

func TestProcessor_ReportsCostOnSuccess(t *testing.T) {
	stub := &adapter.StubAdapter{
		AdapterName: "SeedreamAdapter", AdapterRegion: model.RegionCN,
		Capabilities: []model.Capability{model.CapabilityImageGen}, UnitCost: 8,
	}
	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_cost")
	credit := NewStubCreditClient()
	costStore := costmetering.NewMemoryStore()
	costSvc := costmetering.NewService(costStore)
	proc := newTestProcessor(t, s, BuildDevRouter([]adapter.ModelAdapter{stub}, nil), credit, "stub/in/key")
	proc.costMeter = costSvc

	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}

	records, err := costSvc.TaskCosts(context.Background(), task.ID)
	if err != nil {
		t.Fatalf("TaskCosts() error = %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("cost records = %d, want 1", len(records))
	}
	if records[0].VendorCostCNY != 0.75 {
		t.Fatalf("VendorCostCNY = %v, want 0.75", records[0].VendorCostCNY)
	}
	if records[0].CostCredits != task.CostCredits {
		t.Fatalf("CostCredits = %d, want %d", records[0].CostCredits, task.CostCredits)
	}
}

func TestPool_SubmitAndProcess(t *testing.T) {
	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_pool")
	credit := NewStubCreditClient()
	proc := newTestProcessor(t, s, BuildDevRouter(nil, nil), credit, "stub/in/key")
	pool := NewPool(2, proc)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	pool.Start(ctx)

	if err := pool.Submit(ctx, kafka.TopicImage, kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Submit() error = %v", err)
	}

	deadline := time.Now().Add(2 * time.Second)
	for {
		got, _ := s.GetByID(context.Background(), task.ID)
		if got.State == string(statemachine.StateSucceeded) {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("State = %s, want succeeded", got.State)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestKafkaDispatchingProducerTriggersWorker(t *testing.T) {
	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_kafka")
	credit := NewStubCreditClient()
	proc := newTestProcessor(t, s, BuildDevRouter(nil, nil), credit, "stub/in/key")
	pool := NewPool(1, proc)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	pool.Start(ctx)

	consumer := kafka.NewStubConsumer()
	bridge := kafka.NewWorkerBridge(consumer, pool.Submit)
	if err := bridge.Start(); err != nil {
		t.Fatalf("bridge Start() error = %v", err)
	}

	producer := kafka.NewDispatchingProducer(kafka.NewStubProducer(), consumer)
	if err := producer.Publish(ctx, kafka.TopicImage, kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Publish() error = %v", err)
	}

	deadline := time.Now().Add(2 * time.Second)
	for {
		got, _ := s.GetByID(context.Background(), task.ID)
		if got.State == string(statemachine.StateSucceeded) {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("State = %s, want succeeded", got.State)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestProcessor_RejectsCNTaskWithoutFiling(t *testing.T) {
	s := store.NewMemoryTaskStore()
	task := seedQueuedTask(t, s, "tsk_no_filing")
	credit := NewStubCreditClient()
	modelRouter := router.NewModelRouter(
		DefaultDevAdapters(),
		map[string]adapter.FilingInfo{"SeedreamAdapter": {}},
		router.NewPlayRegistry(router.PlayEntry{
			Style:        "ghibli_kid",
			Region:       model.RegionCN,
			Capability:   model.CapabilityImageGen,
			AdapterNames: []string{"SeedreamAdapter"},
		}),
		router.NewMetricsStore(),
	)
	proc := NewProcessor(s, modelRouter, credit)
	if err := proc.Process(context.Background(), kafka.TaskMessage{
		TaskID: task.ID, UserID: task.UserID, Capability: string(task.Capability), Style: task.Style, Region: string(task.Region),
	}); err != nil {
		t.Fatalf("Process() error = %v", err)
	}
	got, err := s.GetByID(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.State != string(statemachine.StateFailed) {
		t.Fatalf("State = %s, want failed when filing missing", got.State)
	}
}
