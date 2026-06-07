-- feed-svc initial schema (design-backend.md §4.1.2, T5.1)

CREATE TABLE IF NOT EXISTS posts (
    id              TEXT PRIMARY KEY,
    family_id       TEXT NOT NULL,
    owner_user_id   TEXT NOT NULL,
    baby_ids        JSONB NOT NULL DEFAULT '[]'::jsonb,
    caption         TEXT NOT NULL DEFAULT '',
    visibility      TEXT NOT NULL CHECK (visibility IN ('family', 'self')) DEFAULT 'family',
    status          TEXT NOT NULL CHECK (status IN ('audit', 'published', 'removed')) DEFAULT 'audit',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audited_at      TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_posts_family_created ON posts (family_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_owner_user_id ON posts (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_posts_family_active ON posts (family_id, created_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS post_items (
    id              TEXT PRIMARY KEY,
    post_id         TEXT NOT NULL REFERENCES posts (id),
    kind            TEXT NOT NULL CHECK (kind IN ('image', 'video')),
    object_key      TEXT NOT NULL,
    mime            TEXT NOT NULL,
    width           INTEGER NOT NULL,
    height          INTEGER NOT NULL,
    duration        INTEGER,
    deep_synth      BOOLEAN NOT NULL DEFAULT FALSE,
    thumbnail_key   TEXT,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_post_items_post_id ON post_items (post_id);

CREATE TABLE IF NOT EXISTS comments (
    id          TEXT PRIMARY KEY,
    post_id     TEXT NOT NULL REFERENCES posts (id),
    user_id     TEXT NOT NULL,
    parent_id   TEXT REFERENCES comments (id),
    text        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'published',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_comments_post_created ON comments (post_id, created_at);

CREATE TABLE IF NOT EXISTS likes (
    post_id   TEXT NOT NULL REFERENCES posts (id),
    user_id   TEXT NOT NULL,
    liked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS feed_audit_logs (
    id           TEXT PRIMARY KEY,
    target_kind  TEXT NOT NULL,
    target_id    TEXT NOT NULL,
    result       TEXT NOT NULL,
    reasons      JSONB NOT NULL DEFAULT '[]'::jsonb,
    reviewer     TEXT NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_audit_logs_target ON feed_audit_logs (target_kind, target_id);
