-- admin takeover votes + ballots (design-backend.md §4.1.1)
CREATE TABLE IF NOT EXISTS admin_takeover_votes (
    id                  TEXT PRIMARY KEY,
    family_id           TEXT NOT NULL REFERENCES families (id) ON DELETE CASCADE,
    initiator_user_id   TEXT NOT NULL,
    status              TEXT NOT NULL CHECK (status IN ('voting', 'objection_period', 'completed', 'cancelled', 'rejected')),
    opens_at            TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_takeover_votes_family_status
    ON admin_takeover_votes (family_id, status);

CREATE INDEX IF NOT EXISTS idx_admin_takeover_votes_objection_due
    ON admin_takeover_votes (status, ends_at)
    WHERE status = 'objection_period';

CREATE TABLE IF NOT EXISTS admin_takeover_ballots (
    vote_id     TEXT NOT NULL REFERENCES admin_takeover_votes (id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL,
    choice      TEXT NOT NULL CHECK (choice IN ('approve', 'reject')),
    voted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (vote_id, user_id)
);
