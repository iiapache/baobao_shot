-- upload sessions for media-svc direct upload metadata (T3.1)
CREATE TABLE IF NOT EXISTS upload_sessions (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    purpose     TEXT NOT NULL CHECK (purpose IN ('ai-input', 'post-item')),
    family_id   TEXT,
    region      TEXT NOT NULL CHECK (region IN ('cn', 'os')),
    status      TEXT NOT NULL CHECK (status IN ('pending', 'completed')),
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS upload_items (
    id           BIGSERIAL PRIMARY KEY,
    session_id   TEXT NOT NULL REFERENCES upload_sessions (id) ON DELETE CASCADE,
    client_ref   TEXT NOT NULL,
    kind         TEXT,
    mime         TEXT,
    size_bytes   BIGINT,
    sha256       TEXT,
    object_key   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_upload_sessions_user ON upload_sessions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_upload_items_session ON upload_items (session_id);
