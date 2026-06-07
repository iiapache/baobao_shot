-- notification-svc notifications + notification_subscriptions (design-backend.md §4.1.4, T5.8)

CREATE TABLE IF NOT EXISTS notifications (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    category    TEXT NOT NULL CHECK (category IN ('MILESTONE', 'FAMILY_ACTIVITY', 'AI_DONE', 'CREDIT', 'SYSTEM')),
    payload     JSONB NOT NULL DEFAULT '{}',
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications (user_id) WHERE read_at IS NULL;

CREATE TABLE IF NOT EXISTS notification_subscriptions (
    user_id     TEXT NOT NULL,
    category    TEXT NOT NULL CHECK (category IN ('MILESTONE', 'FAMILY_ACTIVITY', 'AI_DONE', 'CREDIT', 'SYSTEM')),
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (user_id, category)
);
