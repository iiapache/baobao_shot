-- credit-sub-ad-svc initial schema (design-backend.md §4.1.3, T4.1)

CREATE TABLE IF NOT EXISTS credit_balances (
    user_id    TEXT PRIMARY KEY,
    balance    BIGINT NOT NULL DEFAULT 0,
    version    BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS credit_ledger (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL,
    type          TEXT NOT NULL CHECK (type IN ('grant', 'charge', 'consume', 'refund', 'adjust')),
    amount        BIGINT NOT NULL,
    ref_kind      TEXT NOT NULL,
    ref_id        TEXT NOT NULL,
    balance_after BIGINT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_credit_ledger_ref ON credit_ledger (ref_kind, ref_id);
CREATE INDEX IF NOT EXISTS idx_credit_ledger_user_created ON credit_ledger (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS credit_holds (
    id         TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL,
    ai_task_id TEXT NOT NULL,
    amount     BIGINT NOT NULL,
    status     TEXT NOT NULL CHECK (status IN ('held', 'committed', 'released')) DEFAULT 'held',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_credit_holds_ai_task ON credit_holds (ai_task_id);

CREATE TABLE IF NOT EXISTS iap_receipts (
    id                      TEXT PRIMARY KEY,
    user_id                 TEXT NOT NULL,
    transaction_id          TEXT NOT NULL,
    original_transaction_id TEXT NOT NULL,
    product_id              TEXT NOT NULL,
    signed_payload          TEXT NOT NULL,
    verified_at             TIMESTAMPTZ NOT NULL,
    status                  TEXT NOT NULL DEFAULT 'verified'
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_iap_receipts_transaction ON iap_receipts (transaction_id);

CREATE TABLE IF NOT EXISTS subscriptions (
    id                      TEXT PRIMARY KEY,
    user_id                 TEXT NOT NULL,
    original_transaction_id TEXT NOT NULL,
    sku                     TEXT NOT NULL,
    period_start            TIMESTAMPTZ NOT NULL,
    period_end              TIMESTAMPTZ NOT NULL,
    state                   TEXT NOT NULL CHECK (state IN ('trial', 'active', 'grace', 'expired', 'refunded')),
    auto_renew              BOOLEAN NOT NULL DEFAULT TRUE,
    last_event_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_subscriptions_original_tx ON subscriptions (original_transaction_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions (user_id);

CREATE TABLE IF NOT EXISTS ad_rewards (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL,
    network         TEXT NOT NULL,
    placement_id    TEXT NOT NULL,
    signature       TEXT NOT NULL,
    granted_credits BIGINT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_ad_rewards_network_sig ON ad_rewards (network, signature);

CREATE TABLE IF NOT EXISTS sign_ins (
    user_id         TEXT NOT NULL,
    date            DATE NOT NULL,
    credits_granted BIGINT NOT NULL,
    streak          INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, date)
);
