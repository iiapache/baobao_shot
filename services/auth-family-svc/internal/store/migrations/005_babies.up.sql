-- babies: baby profiles per family (design-backend.md §4.1.1, T1.9)
CREATE TABLE IF NOT EXISTS babies (
    id            TEXT PRIMARY KEY,
    family_id     TEXT NOT NULL REFERENCES families (id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    full_name     TEXT,
    gender        TEXT NOT NULL CHECK (gender IN ('male', 'female', 'unknown')),
    birth_date    DATE NOT NULL,
    birth_time    TIME,
    birth_weight  REAL,
    birth_length  REAL,
    birth_place   TEXT,
    timezone      TEXT NOT NULL DEFAULT 'UTC',
    avatar_url    TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_babies_family_active ON babies (family_id) WHERE deleted_at IS NULL;
