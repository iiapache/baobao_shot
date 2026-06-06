-- backup provider OAuth metadata + client-reported status (design-api.md §11)
CREATE TABLE IF NOT EXISTS backup_providers (
    id                  TEXT PRIMARY KEY,
    user_id             TEXT NOT NULL REFERENCES users(id),
    kind                TEXT NOT NULL CHECK (kind IN ('icloud', 'baidu_pan', 'photos')),
    access_token        TEXT NOT NULL DEFAULT '',
    refresh_token       TEXT,
    expires_at          TIMESTAMPTZ,
    provider_account_id TEXT,
    metadata            JSONB NOT NULL DEFAULT '{}',
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_backup_providers_user
    ON backup_providers (user_id, created_at);

CREATE TABLE IF NOT EXISTS backup_status (
    user_id         TEXT PRIMARY KEY REFERENCES users(id),
    last_success_at TIMESTAMPTZ,
    last_attempt_at TIMESTAMPTZ,
    failure_count   INT NOT NULL DEFAULT 0,
    last_error_code TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
