-- credit_reconciliation_runs: audit trail for scheduled credit reconciliation (T4.9)

CREATE TABLE IF NOT EXISTS credit_reconciliation_runs (
    id                  TEXT PRIMARY KEY,
    kind                TEXT NOT NULL CHECK (kind IN ('daily', 'manual')),
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,
    status              TEXT NOT NULL CHECK (status IN ('ok', 'discrepancy')),
    discrepancy_count   INTEGER NOT NULL DEFAULT 0,
    report              JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_credit_reconciliation_runs_created
    ON credit_reconciliation_runs (created_at DESC);
