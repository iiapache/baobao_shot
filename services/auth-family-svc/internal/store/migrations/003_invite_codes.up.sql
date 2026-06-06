-- invite_codes (design-backend.md §4.1.1)
CREATE TABLE IF NOT EXISTS invite_codes (
    code        TEXT PRIMARY KEY,
    family_id   TEXT NOT NULL REFERENCES families (id) ON DELETE CASCADE,
    created_by  TEXT NOT NULL,
    expire_at   TIMESTAMPTZ NOT NULL,
    max_uses    INT NOT NULL DEFAULT 8,
    used_count  INT NOT NULL DEFAULT 0,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_family_expire ON invite_codes (family_id, expire_at);
