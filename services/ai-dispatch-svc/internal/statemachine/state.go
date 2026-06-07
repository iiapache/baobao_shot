package statemachine

// State represents an ai_tasks lifecycle state (design-backend §5.4, design.md §5.3).
type State string

const (
	StateCreated        State = "created"
	StateCreditHeld     State = "credit_held"
	StateInputAuditing  State = "input_auditing"
	StateQueued         State = "queued"
	StateRunning        State = "running"
	StateModelFailed    State = "model_failed"
	StateOutputAuditing State = "output_auditing"
	StateWatermarking   State = "watermarking"
	StateSucceeded      State = "succeeded"
	StateFailed         State = "failed"
	StateRejected       State = "rejected"
	StateAppealed       State = "appealed"
	StateCancelled      State = "cancelled"
)

// Event triggers a state transition.
type Event string

const (
	EventCreditHeld           Event = "credit_held"
	EventCancel               Event = "cancel"
	EventInputAuditStart      Event = "input_audit_start"
	EventInputAuditPassed     Event = "input_audit_passed"
	EventInputAuditRejected   Event = "input_audit_rejected"
	EventWorkerPulled         Event = "worker_pulled"
	EventModelError           Event = "model_error"
	EventRetry                Event = "retry"
	EventRetriesExhausted     Event = "retries_exhausted"
	EventModelReturned        Event = "model_returned"
	EventOutputAuditPassed    Event = "output_audit_passed"
	EventOutputAuditRejected  Event = "output_audit_rejected"
	EventWatermarkComplete    Event = "watermark_complete"
	EventPersisted            Event = "persisted"
	EventAppeal               Event = "appeal"
)

// SideEffect describes post-transition actions (design-backend §5.4).
type SideEffect string

const (
	SideEffectNone         SideEffect = ""
	SideEffectCreditHold   SideEffect = "credit_hold"
	SideEffectKafkaEnqueue SideEffect = "kafka_enqueue"
	SideEffectCreditCommit SideEffect = "credit_commit"
	SideEffectCreditRefund SideEffect = "credit_refund"
	SideEffectNotify       SideEffect = "notify"
)

// TransitionResult is the outcome of applying an event to a state.
type TransitionResult struct {
	From       State
	To         State
	Event      Event
	SideEffect SideEffect
}

// AllStates returns every defined state for test coverage enumeration.
func AllStates() []State {
	return []State{
		StateCreated,
		StateCreditHeld,
		StateInputAuditing,
		StateQueued,
		StateRunning,
		StateModelFailed,
		StateOutputAuditing,
		StateWatermarking,
		StateSucceeded,
		StateFailed,
		StateRejected,
		StateAppealed,
		StateCancelled,
	}
}

// IsTerminal reports whether no further transitions are allowed.
func IsTerminal(s State) bool {
	switch s {
	case StateSucceeded, StateFailed, StateRejected, StateAppealed, StateCancelled:
		return true
	default:
		return false
	}
}
