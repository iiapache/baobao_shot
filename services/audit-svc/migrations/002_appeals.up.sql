-- appeals: user appeals for rejected audit jobs (design-backend.md §4.1.5, T3.3)
CREATE TABLE IF NOT EXISTS appeals (
    id            TEXT PRIMARY KEY,
    audit_job_id  TEXT NOT NULL REFERENCES audit_jobs (id),
    user_id       TEXT NOT NULL,
    reason        TEXT NOT NULL,
    status        TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_appeals_user_id ON appeals (user_id);
CREATE INDEX IF NOT EXISTS idx_appeals_status ON appeals (status);
CREATE INDEX IF NOT EXISTS idx_appeals_audit_job_id ON appeals (audit_job_id);
