package audit

import (
	"errors"
	"testing"
	"time"

	"github.com/baobao/audit-svc/internal/model"
)

func TestCanTransition(t *testing.T) {
	cases := []struct {
		from model.AuditStatus
		to   model.AuditStatus
		want bool
	}{
		{model.AuditStatusPending, model.AuditStatusPassed, true},
		{model.AuditStatusPending, model.AuditStatusRejected, true},
		{model.AuditStatusPending, model.AuditStatusPending, true},
		{model.AuditStatusPassed, model.AuditStatusRejected, false},
		{model.AuditStatusRejected, model.AuditStatusPassed, false},
	}
	for _, tc := range cases {
		if got := CanTransition(tc.from, tc.to); got != tc.want {
			t.Fatalf("CanTransition(%s,%s)=%v want %v", tc.from, tc.to, got, tc.want)
		}
	}
}

func TestApplyTransition(t *testing.T) {
	now := time.Date(2026, 6, 6, 12, 0, 0, 0, time.UTC)
	job := &model.AuditJob{Status: model.AuditStatusPending}
	if err := ApplyTransition(job, model.AuditStatusPassed, "passed", nil, "stub", now); err != nil {
		t.Fatalf("ApplyTransition: %v", err)
	}
	if job.Status != model.AuditStatusPassed || job.CompletedAt == nil {
		t.Fatalf("unexpected job: %+v", job)
	}

	job.Status = model.AuditStatusPassed
	err := ApplyTransition(job, model.AuditStatusRejected, "rejected", []string{"x"}, "stub", now)
	if !errors.Is(err, ErrInvalidTransition) {
		t.Fatalf("expected ErrInvalidTransition, got %v", err)
	}
}
