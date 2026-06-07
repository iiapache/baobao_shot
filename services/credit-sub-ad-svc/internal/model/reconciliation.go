package model

import "time"

// ReconciliationRunKind identifies how a reconciliation run was triggered.
type ReconciliationRunKind string

const (
	ReconciliationDaily  ReconciliationRunKind = "daily"
	ReconciliationManual ReconciliationRunKind = "manual"
)

// ReconciliationStatus is the outcome of a reconciliation run.
type ReconciliationStatus string

const (
	ReconciliationOK           ReconciliationStatus = "ok"
	ReconciliationDiscrepancy  ReconciliationStatus = "discrepancy"
)

// ReconciliationRun is an audit row for one reconciliation execution.
type ReconciliationRun struct {
	ID                 string
	Kind               ReconciliationRunKind
	PeriodStart        time.Time
	PeriodEnd          time.Time
	Status             ReconciliationStatus
	DiscrepancyCount   int
	Report             map[string]any
	CreatedAt          time.Time
}
