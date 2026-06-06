-- account deletion grace period + data export request entry (design-backend.md §4.1.1)
CREATE TABLE IF NOT EXISTS account_deletions (
    user_id       TEXT PRIMARY KEY REFERENCES users(id),
    requested_at  TIMESTAMPTZ NOT NULL,
    scheduled_at  TIMESTAMPTZ NOT NULL,
    cancelled_at  TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_account_deletions_scheduled
    ON account_deletions (scheduled_at)
    WHERE cancelled_at IS NULL AND completed_at IS NULL;

CREATE TABLE IF NOT EXISTS data_export_requests (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES users(id),
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    requested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_data_export_requests_user_pending
    ON data_export_requests (user_id, requested_at DESC)
    WHERE status IN ('pending', 'processing');
