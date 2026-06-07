package statemachine

import (
	"errors"
	"testing"
)

func TestHappyPathTransitions(t *testing.T) {
	path := []struct {
		from  State
		event Event
		to    State
	}{
		{StateCreated, EventCreditHeld, StateCreditHeld},
		{StateCreditHeld, EventInputAuditStart, StateInputAuditing},
		{StateInputAuditing, EventInputAuditPassed, StateQueued},
		{StateQueued, EventWorkerPulled, StateRunning},
		{StateRunning, EventModelReturned, StateOutputAuditing},
		{StateOutputAuditing, EventOutputAuditPassed, StateWatermarking},
		{StateWatermarking, EventPersisted, StateSucceeded},
	}

	for _, step := range path {
		t.Run(string(step.from)+"_"+string(step.event), func(t *testing.T) {
			result, err := Transition(step.from, step.event)
			if err != nil {
				t.Fatalf("Transition() error = %v", err)
			}
			if result.To != step.to {
				t.Fatalf("To = %s, want %s", result.To, step.to)
			}
		})
	}
}

func TestInputAuditRejected(t *testing.T) {
	result, err := Transition(StateInputAuditing, EventInputAuditRejected)
	if err != nil {
		t.Fatalf("Transition() error = %v", err)
	}
	if result.To != StateRejected {
		t.Fatalf("To = %s, want rejected", result.To)
	}
	effects := SideEffects(result)
	if !containsEffect(effects, SideEffectCreditRefund) || !containsEffect(effects, SideEffectNotify) {
		t.Fatalf("effects = %v, want credit_refund + notify", effects)
	}
}

func TestOutputAuditRejected(t *testing.T) {
	result, err := Transition(StateOutputAuditing, EventOutputAuditRejected)
	if err != nil {
		t.Fatalf("Transition() error = %v", err)
	}
	if result.To != StateRejected {
		t.Fatalf("To = %s, want rejected", result.To)
	}
}

func TestModelRetryPath(t *testing.T) {
	result, err := Transition(StateRunning, EventModelError)
	if err != nil {
		t.Fatalf("Transition() error = %v", err)
	}
	if result.To != StateModelFailed {
		t.Fatalf("To = %s, want model_failed", result.To)
	}

	retry, err := Transition(StateModelFailed, EventRetry)
	if err != nil {
		t.Fatalf("retry Transition() error = %v", err)
	}
	if retry.To != StateRunning {
		t.Fatalf("retry To = %s, want running", retry.To)
	}

	exhausted, err := Transition(StateModelFailed, EventRetriesExhausted)
	if err != nil {
		t.Fatalf("exhausted Transition() error = %v", err)
	}
	if exhausted.To != StateFailed {
		t.Fatalf("To = %s, want failed", exhausted.To)
	}
}

func TestNextEventAfterModelError(t *testing.T) {
	if NextEventAfterModelError(0) != EventRetry {
		t.Fatal("retry 0 should retry")
	}
	if NextEventAfterModelError(1) != EventRetry {
		t.Fatal("retry 1 should retry")
	}
	if NextEventAfterModelError(2) != EventRetriesExhausted {
		t.Fatal("retry 2 should exhaust")
	}
}

func TestCancelFromEarlyStates(t *testing.T) {
	states := []State{StateCreated, StateCreditHeld, StateInputAuditing}
	for _, from := range states {
		t.Run(string(from), func(t *testing.T) {
			result, err := Transition(from, EventCancel)
			if err != nil {
				t.Fatalf("Transition() error = %v", err)
			}
			if result.To != StateCancelled {
				t.Fatalf("To = %s, want cancelled", result.To)
			}
		})
	}
}

func TestCancelNotAllowedAfterQueued(t *testing.T) {
	for _, from := range []State{StateQueued, StateRunning, StateSucceeded} {
		if CanTransition(from, EventCancel) {
			t.Fatalf("cancel should not be allowed from %s", from)
		}
	}
}

func TestAppealTransition(t *testing.T) {
	result, err := Transition(StateRejected, EventAppeal)
	if err != nil {
		t.Fatalf("Transition() error = %v", err)
	}
	if result.To != StateAppealed {
		t.Fatalf("To = %s, want appealed", result.To)
	}
}

func TestTerminalStatesRejectTransitions(t *testing.T) {
	terminals := []State{StateSucceeded, StateFailed, StateRejected, StateAppealed, StateCancelled}
	for _, s := range terminals {
		if s == StateRejected {
			if !CanTransition(s, EventAppeal) {
				t.Fatalf("appeal should be allowed from rejected")
			}
			continue
		}
		if !IsTerminal(s) {
			t.Fatalf("%s should be terminal", s)
		}
		_, err := Transition(s, EventCreditHeld)
		if !errors.Is(err, ErrTerminalState) {
			t.Fatalf("Transition from %s: err = %v, want ErrTerminalState", s, err)
		}
	}
}

func TestInvalidTransitions(t *testing.T) {
	cases := []struct {
		from  State
		event Event
	}{
		{StateCreated, EventWorkerPulled},
		{StateQueued, EventModelReturned},
		{StateRunning, EventInputAuditPassed},
		{StateWatermarking, EventCancel},
	}
	for _, tc := range cases {
		t.Run(string(tc.from)+"_"+string(tc.event), func(t *testing.T) {
			_, err := Transition(tc.from, tc.event)
			if !errors.Is(err, ErrInvalidTransition) {
				t.Fatalf("err = %v, want ErrInvalidTransition", err)
			}
		})
	}
}

func TestSideEffectsDesignSection54(t *testing.T) {
	cases := []struct {
		from   State
		event  Event
		effect SideEffect
	}{
		{StateCreated, EventCreditHeld, SideEffectCreditHold},
		{StateInputAuditing, EventInputAuditPassed, SideEffectKafkaEnqueue},
		{StateWatermarking, EventPersisted, SideEffectCreditCommit},
		{StateModelFailed, EventRetriesExhausted, SideEffectCreditRefund},
	}
	for _, tc := range cases {
		t.Run(string(tc.event), func(t *testing.T) {
			result, err := Transition(tc.from, tc.event)
			if err != nil {
				t.Fatalf("Transition() error = %v", err)
			}
			if result.SideEffect != tc.effect {
				t.Fatalf("SideEffect = %s, want %s", result.SideEffect, tc.effect)
			}
		})
	}
}

func TestAllNonTerminalStatesHaveTransitions(t *testing.T) {
	for _, s := range AllStates() {
		if IsTerminal(s) {
			continue
		}
		if len(AllowedEvents(s)) == 0 {
			t.Fatalf("state %s has no allowed events", s)
		}
	}
}

func containsEffect(effects []SideEffect, want SideEffect) bool {
	for _, e := range effects {
		if e == want {
			return true
		}
	}
	return false
}
