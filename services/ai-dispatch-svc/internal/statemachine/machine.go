package statemachine

import (
	"errors"
	"fmt"
)

// MaxModelRetries is the model-layer retry ceiling (design-backend §5.5).
const MaxModelRetries = 2

var (
	ErrInvalidTransition = errors.New("invalid state transition")
	ErrTerminalState     = errors.New("task is in terminal state")
)

type transitionDef struct {
	to         State
	sideEffect SideEffect
}

// transitions maps (from, event) → (to, sideEffect).
// Covers design-backend §5.4 and design.md §5.3 (incl. model_failed retry path).
var transitions = map[State]map[Event]transitionDef{
	StateCreated: {
		EventCreditHeld: {to: StateCreditHeld, sideEffect: SideEffectCreditHold},
		EventCancel:     {to: StateCancelled, sideEffect: SideEffectCreditRefund},
	},
	StateCreditHeld: {
		EventInputAuditStart: {to: StateInputAuditing},
		EventCancel:          {to: StateCancelled, sideEffect: SideEffectCreditRefund},
	},
	StateInputAuditing: {
		EventInputAuditPassed:   {to: StateQueued, sideEffect: SideEffectKafkaEnqueue},
		EventInputAuditRejected: {to: StateRejected, sideEffect: SideEffectCreditRefund},
		EventCancel:             {to: StateCancelled, sideEffect: SideEffectCreditRefund},
	},
	StateQueued: {
		EventWorkerPulled: {to: StateRunning},
	},
	StateRunning: {
		EventModelError:    {to: StateModelFailed},
		EventModelReturned: {to: StateOutputAuditing},
	},
	StateModelFailed: {
		EventRetry:            {to: StateRunning},
		EventRetriesExhausted: {to: StateFailed, sideEffect: SideEffectCreditRefund},
	},
	StateOutputAuditing: {
		EventOutputAuditPassed:   {to: StateWatermarking},
		EventOutputAuditRejected: {to: StateRejected, sideEffect: SideEffectCreditRefund},
	},
	StateWatermarking: {
		EventPersisted: {to: StateSucceeded, sideEffect: SideEffectCreditCommit},
	},
}

// CanTransition reports whether event is valid for the current state.
func CanTransition(from State, event Event) bool {
	_, err := Transition(from, event)
	return err == nil
}

// Transition applies event to from and returns the next state with side effects.
func Transition(from State, event Event) (TransitionResult, error) {
	if from == StateRejected && event == EventAppeal {
		return TransitionResult{
			From:  from,
			To:    StateAppealed,
			Event: event,
		}, nil
	}
	if IsTerminal(from) {
		return TransitionResult{}, fmt.Errorf("%w: %s", ErrTerminalState, from)
	}

	events, ok := transitions[from]
	if !ok {
		return TransitionResult{}, fmt.Errorf("%w: no transitions from %s", ErrInvalidTransition, from)
	}

	def, ok := events[event]
	if !ok {
		return TransitionResult{}, fmt.Errorf("%w: %s on %s", ErrInvalidTransition, event, from)
	}

	result := TransitionResult{
		From:       from,
		To:         def.to,
		Event:      event,
		SideEffect: def.sideEffect,
	}
	if result.SideEffect == SideEffectCreditCommit || result.SideEffect == SideEffectCreditRefund {
		// Notify accompanies credit settlement paths (design-backend §5.4).
		_ = result // side effect notify is composed at orchestration layer
	}
	return result, nil
}

// SideEffects returns all side effects for a transition (primary + composed).
func SideEffects(result TransitionResult) []SideEffect {
	if result.SideEffect == SideEffectNone {
		return nil
	}
	effects := []SideEffect{result.SideEffect}
	switch result.SideEffect {
	case SideEffectCreditCommit, SideEffectCreditRefund:
		effects = append(effects, SideEffectNotify)
	case SideEffectKafkaEnqueue:
		// enqueue only; notify happens on terminal states
	}
	return effects
}

// NextEventAfterModelError picks retry vs exhausted based on current retry count.
func NextEventAfterModelError(retryCount int) Event {
	if retryCount < MaxModelRetries {
		return EventRetry
	}
	return EventRetriesExhausted
}

// AllowedEvents returns valid events for a non-terminal state.
func AllowedEvents(from State) []Event {
	if IsTerminal(from) {
		return nil
	}
	events, ok := transitions[from]
	if !ok {
		return nil
	}
	out := make([]Event, 0, len(events))
	for e := range events {
		out = append(out, e)
	}
	return out
}
