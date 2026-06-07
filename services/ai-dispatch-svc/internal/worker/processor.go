package worker

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
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

// Processor executes queued AI tasks with routing, timeouts, and model retries.
type Processor struct {
	store         store.TaskStore
	router        *router.ModelRouter
	credit        CreditClient
	costMeter     *costmetering.Service
	watermarker   *watermark.Pipeline
	filings       map[string]adapter.FilingInfo
	sleepFn       func(time.Duration)
	invokeTimeout func(model.Capability) time.Duration
}

// ProcessorOption configures optional processor behavior.
type ProcessorOption func(*Processor)

// WithSleepFn overrides backoff sleep (tests).
func WithSleepFn(fn func(time.Duration)) ProcessorOption {
	return func(p *Processor) {
		p.sleepFn = fn
	}
}

// WithInvokeTimeout overrides per-capability invoke deadlines (tests).
func WithInvokeTimeout(fn func(model.Capability) time.Duration) ProcessorOption {
	return func(p *Processor) {
		p.invokeTimeout = fn
	}
}

// WithArtifactStore configures the watermark pipeline artifact backend (tests/dev).
func WithArtifactStore(store watermark.ArtifactStore) ProcessorOption {
	return func(p *Processor) {
		p.watermarker = watermark.NewPipeline(store)
	}
}

// WithFilings supplies adapter filing numbers for deepSynth.manifest.
func WithFilings(filings map[string]adapter.FilingInfo) ProcessorOption {
	return func(p *Processor) {
		p.filings = filings
	}
}

// WithCostMetering wires vendor cost reporting after successful model invocations.
func WithCostMetering(svc *costmetering.Service) ProcessorOption {
	return func(p *Processor) {
		p.costMeter = svc
	}
}

// NewProcessor creates a task processor.
func NewProcessor(taskStore store.TaskStore, modelRouter *router.ModelRouter, credit CreditClient, opts ...ProcessorOption) *Processor {
	if credit == nil {
		credit = NewStubCreditClient()
	}
	p := &Processor{
		store:       taskStore,
		router:      modelRouter,
		credit:      credit,
		watermarker: watermark.NewPipeline(watermark.NewMemoryArtifactStore()),
		sleepFn:     time.Sleep,
	}
	for _, opt := range opts {
		opt(p)
	}
	return p
}

// Process handles one Kafka task message end-to-end.
func (p *Processor) Process(ctx context.Context, msg kafka.TaskMessage) error {
	if msg.TaskID == "" {
		return fmt.Errorf("taskId required")
	}

	task, err := p.store.GetByID(ctx, msg.TaskID)
	if err != nil {
		return fmt.Errorf("load task: %w", err)
	}
	if task.State != string(statemachine.StateQueued) {
		slog.Debug("skip non-queued task", "taskId", msg.TaskID, "state", task.State)
		return nil
	}

	if _, err := p.transition(ctx, task, statemachine.StateQueued, statemachine.EventWorkerPulled); err != nil {
		return err
	}

	task, err = p.store.GetByID(ctx, msg.TaskID)
	if err != nil {
		return err
	}
	return p.runModel(ctx, task, msg)
}

func (p *Processor) runModel(ctx context.Context, task *model.Task, msg kafka.TaskMessage) error {
	capability := model.Capability(msg.Capability)
	if capability == "" {
		capability = task.Capability
	}
	region := model.Region(msg.Region)
	if region == "" {
		region = task.Region
	}
	style := msg.Style
	if style == "" {
		style = task.Style
	}

	for {
		task, err := p.store.GetByID(ctx, task.ID)
		if err != nil {
			return err
		}

		routeResult, err := p.router.Route(router.RouteRequest{
			Region:     region,
			Style:      style,
			Capability: capability,
		})
		if err != nil {
			return p.handleTerminal(ctx, task, statemachine.StateRunning, statemachine.EventModelError, err)
		}

		selected := routeResult.Adapter
		metrics := p.router.Metrics()
		metrics.SetLoad(selected.Name(), metrics.Load(selected.Name())+1)

		invokeCtx, cancel := context.WithTimeout(ctx, p.timeoutFor(capability))
		start := time.Now()
		output, invokeErr := selected.Invoke(invokeCtx, adapter.InvokeRequest{
			Style:           style,
			Capability:      capability,
			Region:          region,
			Input:           task.Input,
			DurationSeconds: defaultVideoDuration(capability),
		})
		cancel()
		latencyMs := time.Since(start).Milliseconds()

		metrics.SetLoad(selected.Name(), metrics.Load(selected.Name())-1)
		_ = p.appendInvocation(ctx, task.ID, selected.Name(), latencyMs, task.ModelRetryCount)

		if invokeErr == nil {
			metrics.RecordOutcome(selected.Name(), true)
			_ = p.reportCost(ctx, task, selected, capability, region, style, latencyMs)
			return p.handleModelSuccess(ctx, task, selected.Name(), output)
		}

		metrics.RecordOutcome(selected.Name(), false)
		if errors.Is(invokeErr, context.DeadlineExceeded) {
			invokeErr = adapter.NewAdapterError(adapter.ErrCodeTransient, "TIMEOUT", "invoke timeout")
		}

		if !adapter.IsRetryable(invokeErr) {
			return p.handleRejected(ctx, task, invokeErr)
		}

		if _, err := p.transition(ctx, task, statemachine.StateRunning, statemachine.EventModelError); err != nil {
			return err
		}

		task, err = p.store.GetByID(ctx, task.ID)
		if err != nil {
			return err
		}

		if statemachine.NextEventAfterModelError(task.ModelRetryCount) == statemachine.EventRetriesExhausted {
			return p.handleFailed(ctx, task, invokeErr)
		}

		p.sleepFn(RetryBackoff(task.ModelRetryCount))

		nextRetry := task.ModelRetryCount + 1
		at := time.Now().UTC()
		if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
			ModelRetryCount: &nextRetry,
			UpdatedAt:       at,
		}); err != nil {
			return err
		}

		task, err = p.store.GetByID(ctx, task.ID)
		if err != nil {
			return err
		}
		if _, err := p.transition(ctx, task, statemachine.StateModelFailed, statemachine.EventRetry); err != nil {
			return err
		}
	}
}

func (p *Processor) handleModelSuccess(ctx context.Context, task *model.Task, modelName string, output adapter.InvokeOutput) error {
	result, err := statemachine.Transition(statemachine.StateRunning, statemachine.EventModelReturned)
	if err != nil {
		return err
	}
	at := time.Now().UTC()
	patch := store.TaskPatch{
		State:     string(result.To),
		Model:     &modelName,
		Output:    &model.TaskOutput{ObjectKey: output.ObjectKey, ThumbnailKey: output.ThumbnailKey},
		UpdatedAt: at,
	}
	if err := p.store.UpdateTask(ctx, task.ID, patch); err != nil {
		return err
	}
	return p.finalizeOutput(ctx, task, modelName, output)
}

func (p *Processor) finalizeOutput(ctx context.Context, task *model.Task, modelName string, output adapter.InvokeOutput) error {
	task, err := p.store.GetByID(ctx, task.ID)
	if err != nil {
		return err
	}

	if _, err := p.transition(ctx, task, statemachine.StateOutputAuditing, statemachine.EventOutputAuditPassed); err != nil {
		return err
	}

	task, err = p.store.GetByID(ctx, task.ID)
	if err != nil {
		return err
	}

	wmResult, err := p.watermarker.Apply(ctx, watermark.Input{
		TaskID:       task.ID,
		Vendor:       modelName,
		Model:        modelName,
		Capability:   task.Capability,
		PromptHash:   task.Input.SHA256,
		FilingNo:     p.filingNo(modelName),
		ObjectKey:    output.ObjectKey,
		ThumbnailKey: output.ThumbnailKey,
	})
	if err != nil {
		return fmt.Errorf("watermark apply: %w", err)
	}

	at := time.Now().UTC()
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		Output: &model.TaskOutput{
			ObjectKey:    wmResult.ObjectKey,
			ThumbnailKey: wmResult.ThumbnailKey,
		},
		DeepSynth: &wmResult.DeepSynth,
		UpdatedAt: at,
	}); err != nil {
		return err
	}

	task, err = p.store.GetByID(ctx, task.ID)
	if err != nil {
		return err
	}

	result, err := statemachine.Transition(statemachine.StateWatermarking, statemachine.EventPersisted)
	if err != nil {
		return err
	}
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		State:     string(result.To),
		UpdatedAt: at,
	}); err != nil {
		return err
	}
	return p.applySideEffects(ctx, task, statemachine.SideEffects(result))
}

func (p *Processor) filingNo(modelName string) string {
	if p.filings == nil {
		return ""
	}
	if filing, ok := p.filings[modelName]; ok {
		return filing.DeepSynthFilingNo
	}
	return ""
}

func (p *Processor) handleRejected(ctx context.Context, task *model.Task, cause error) error {
	slog.Info("model rejected", "taskId", task.ID, "error", cause)
	at := time.Now().UTC()
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		State:     string(statemachine.StateRejected),
		UpdatedAt: at,
	}); err != nil {
		return err
	}
	return p.applySideEffects(ctx, task, []statemachine.SideEffect{
		statemachine.SideEffectCreditRefund,
		statemachine.SideEffectNotify,
	})
}

func (p *Processor) handleFailed(ctx context.Context, task *model.Task, cause error) error {
	slog.Info("model retries exhausted", "taskId", task.ID, "retries", task.ModelRetryCount, "error", cause)
	result, err := statemachine.Transition(statemachine.StateModelFailed, statemachine.EventRetriesExhausted)
	if err != nil {
		return err
	}
	at := time.Now().UTC()
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		State:     string(result.To),
		UpdatedAt: at,
	}); err != nil {
		return err
	}
	return p.applySideEffects(ctx, task, statemachine.SideEffects(result))
}

func (p *Processor) handleTerminal(ctx context.Context, task *model.Task, from statemachine.State, event statemachine.Event, cause error) error {
	slog.Warn("task terminal from routing", "taskId", task.ID, "error", cause)
	result, err := statemachine.Transition(from, event)
	if err != nil {
		return err
	}
	exhausted, err := statemachine.Transition(result.To, statemachine.EventRetriesExhausted)
	if err != nil {
		return err
	}
	at := time.Now().UTC()
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		State:     string(exhausted.To),
		UpdatedAt: at,
	}); err != nil {
		return err
	}
	return p.applySideEffects(ctx, task, statemachine.SideEffects(exhausted))
}

func (p *Processor) transition(ctx context.Context, task *model.Task, from statemachine.State, event statemachine.Event) (statemachine.TransitionResult, error) {
	current := statemachine.State(task.State)
	if current != from {
		from = current
	}
	result, err := statemachine.Transition(from, event)
	if err != nil {
		return result, err
	}
	at := time.Now().UTC()
	if err := p.store.UpdateTask(ctx, task.ID, store.TaskPatch{
		State:     string(result.To),
		UpdatedAt: at,
	}); err != nil {
		return result, err
	}
	return result, nil
}

func (p *Processor) appendInvocation(ctx context.Context, taskID, vendor string, latencyMs int64, retry int) error {
	inv := model.ModelInvocation{Vendor: vendor, LatencyMs: latencyMs, Retry: retry}
	return p.store.UpdateTask(ctx, taskID, store.TaskPatch{
		AppendInvocation: &inv,
		UpdatedAt:        time.Now().UTC(),
	})
}

func (p *Processor) reportCost(
	ctx context.Context,
	task *model.Task,
	selected adapter.ModelAdapter,
	capability model.Capability,
	region model.Region,
	style string,
	latencyMs int64,
) error {
	if p.costMeter == nil {
		return nil
	}
	return p.costMeter.ReportInvocation(ctx, costmetering.ReportRequest{
		Task:      task,
		Vendor:    selected.Name(),
		Adapter:   selected,
		InvokeReq: adapter.InvokeRequest{Style: style, Capability: capability, Region: region, Input: task.Input, DurationSeconds: defaultVideoDuration(capability)},
		LatencyMs: latencyMs,
		Retry:     task.ModelRetryCount,
	})
}

func (p *Processor) applySideEffects(ctx context.Context, task *model.Task, effects []statemachine.SideEffect) error {
	for _, effect := range effects {
		switch effect {
		case statemachine.SideEffectCreditRefund:
			if task.CreditHoldID == "" {
				continue
			}
			if err := p.credit.Release(ctx, NormalizeRelease(SettleRequest{
				HoldID: task.CreditHoldID,
				TaskID: task.ID,
			})); err != nil {
				return fmt.Errorf("credit release: %w", err)
			}
		case statemachine.SideEffectCreditCommit:
			if task.CreditHoldID == "" {
				continue
			}
			if err := p.credit.Commit(ctx, NormalizeCommit(SettleRequest{
				HoldID: task.CreditHoldID,
				TaskID: task.ID,
			})); err != nil {
				return fmt.Errorf("credit commit: %w", err)
			}
		case statemachine.SideEffectNotify:
			// notification-svc integration deferred to T3.17+ orchestration.
		}
	}
	return nil
}

func defaultVideoDuration(capability model.Capability) int {
	if capability == model.CapabilityVideoGen {
		return 5
	}
	return 0
}

func (p *Processor) timeoutFor(capability model.Capability) time.Duration {
	if p.invokeTimeout != nil {
		return p.invokeTimeout(capability)
	}
	return InvokeTimeout(capability)
}
