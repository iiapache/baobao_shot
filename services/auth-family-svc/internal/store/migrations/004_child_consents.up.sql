-- child_consents: versioned guardian consent audit trail (T1.10)
CREATE TABLE IF NOT EXISTS child_consents (
    user_id    TEXT NOT NULL REFERENCES users (id),
    version    TEXT NOT NULL,
    agreed_at  TIMESTAMPTZ NOT NULL,
    ip         TEXT NOT NULL DEFAULT '',
    device_id  TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (user_id, version)
);

CREATE INDEX IF NOT EXISTS idx_child_consents_user_id ON child_consents (user_id);
