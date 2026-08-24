-- Warehouse billing schema
-- Applied automatically on first postgres startup via docker-compose volume mount

CREATE TABLE IF NOT EXISTS events (
    event_id        TEXT PRIMARY KEY,
    merchant_id     TEXT        NOT NULL,
    warehouse_id    TEXT        NOT NULL,
    event_type      TEXT        NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    raw_payload     JSONB       NOT NULL,
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS charges (
    charge_id        BIGSERIAL PRIMARY KEY,
    event_id         TEXT        NOT NULL REFERENCES events(event_id),
    merchant_id      TEXT        NOT NULL,
    amount           NUMERIC(12, 4) NOT NULL,
    rate_card_version TEXT       NOT NULL,
    calculated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS errors (
    error_id    BIGSERIAL PRIMARY KEY,
    event_id    TEXT,   -- nullable: schema errors may have no valid event_id
    category    TEXT    NOT NULL,  -- schema | business_logic | reference | duplicate | time_anomaly
    details     TEXT    NOT NULL,
    raw_payload JSONB,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Written by the pipeline at the end of each run
CREATE TABLE IF NOT EXISTS audit_summary (
    run_id           BIGSERIAL PRIMARY KEY,
    run_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    events_generated INT         NOT NULL,
    errors_injected  INT         NOT NULL,
    errors_detected  INT         NOT NULL,
    detection_rate   NUMERIC(5, 2) NOT NULL  -- percentage, e.g. 94.12
);

CREATE INDEX IF NOT EXISTS idx_events_merchant   ON events(merchant_id);
CREATE INDEX IF NOT EXISTS idx_events_timestamp  ON events(event_timestamp);
CREATE INDEX IF NOT EXISTS idx_errors_category   ON errors(category);
