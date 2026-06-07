-- notification-svc device_tokens (design-backend.md §4.1.4, T5.7)

CREATE TABLE IF NOT EXISTS device_tokens (
    user_id       TEXT NOT NULL,
    device_id     TEXT NOT NULL,
    apns_token    TEXT NOT NULL,
    region        TEXT NOT NULL CHECK (region IN ('cn', 'os')),
    app_version   TEXT NOT NULL DEFAULT '',
    os_version    TEXT NOT NULL DEFAULT '',
    model         TEXT NOT NULL DEFAULT '',
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_apns_token ON device_tokens (apns_token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens (user_id);
