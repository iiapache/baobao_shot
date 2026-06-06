-- phone verification codes (design-backend.md §4.3 sms:{region}:{phone} TTL 5m)
CREATE TABLE IF NOT EXISTS phone_verification_codes (
    id          BIGSERIAL PRIMARY KEY,
    phone       TEXT NOT NULL,
    region      TEXT NOT NULL DEFAULT 'cn' CHECK (region IN ('cn', 'os')),
    code_hash   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_phone_verification_codes_phone_created
    ON phone_verification_codes (phone, region, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_phone_verification_codes_expires
    ON phone_verification_codes (expires_at);
