-- auth-family-svc users table (design-backend.md §4.1.1)
CREATE TABLE IF NOT EXISTS users (
    id              TEXT PRIMARY KEY,
    apple_sub       TEXT,
    phone           TEXT,
    region          TEXT NOT NULL CHECK (region IN ('cn', 'os')),
    nickname        TEXT NOT NULL DEFAULT '',
    avatar_url      TEXT,
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    child_data_consent_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_users_apple_sub ON users (apple_sub) WHERE apple_sub IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_users_phone_region ON users (phone, region) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON users (last_seen_at);
