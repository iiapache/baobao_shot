-- audit_jobs: content audit job records (design-backend.md §4.1.5, T3.3)
CREATE TABLE IF NOT EXISTS audit_jobs (
    id           TEXT PRIMARY KEY,
    kind         TEXT NOT NULL CHECK (kind IN ('input', 'output', 'ugc')),
    target_ref   TEXT NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('pending', 'passed', 'rejected')) DEFAULT 'pending',
    result       TEXT,
    reasons      JSONB NOT NULL DEFAULT '[]'::jsonb,
    vendor       TEXT,
    region       TEXT NOT NULL DEFAULT 'cn' CHECK (region IN ('cn', 'os')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_audit_jobs_status_created ON audit_jobs (status, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_jobs_target_ref ON audit_jobs (target_ref);
