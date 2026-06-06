-- families + memberships (design-backend.md §4.1.1)
CREATE TABLE IF NOT EXISTS families (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    admin_user_id   TEXT NOT NULL,
    region          TEXT NOT NULL CHECK (region IN ('cn', 'os')),
    plan            TEXT NOT NULL DEFAULT 'free',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_families_admin_user_id ON families (admin_user_id);

CREATE TABLE IF NOT EXISTS memberships (
    user_id     TEXT NOT NULL,
    family_id   TEXT NOT NULL REFERENCES families (id) ON DELETE CASCADE,
    role        TEXT NOT NULL CHECK (role IN ('admin', 'family', 'guest')),
    nickname    TEXT NOT NULL DEFAULT '',
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    removed_at  TIMESTAMPTZ,
    PRIMARY KEY (user_id, family_id)
);

CREATE INDEX IF NOT EXISTS idx_memberships_family_id ON memberships (family_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user_active ON memberships (user_id) WHERE removed_at IS NULL;
