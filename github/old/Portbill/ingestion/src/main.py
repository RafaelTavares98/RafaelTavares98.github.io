"""
Portbill — pipeline orchestrator.

Responsibility split:
  - generator/      builds raw events (replaceable with a real WMS webhook)
  - validators.py   tags events with one of five error categories
  - lua_runner.py   prices a clean event via its merchant's Lua rate card
  - main.py         (this file) glues them together and persists to Postgres

Why a single orchestrator file:
  This is an MVP pipeline, not a workflow engine. Airflow/Dagster would buy
  scheduling and observability we don't need yet — the cost is more setup
  time than the entire rest of the project. A `while True: ... time.sleep()`
  loop running inside Docker is enough until proven otherwise.

Run model:
  - First container start  → seed 3 months of history (~1 800 events).
  - Every subsequent hour  → generate a small Poisson-sized batch.
  - Each batch is a transaction; a crash mid-batch rolls back atomically.
"""

import os
import random
import time

import psycopg
from psycopg.types.json import Jsonb

from generator.src.generator import generate_backlog, hourly_batch, inject_error
from ingestion.src.lua_runner import calculate_charge
from ingestion.src.validators import validate_event

# Error injection rate (2 %). Low enough to keep revenue numbers realistic,
# high enough that a 1 800-event backlog still produces ~36 errors — a
# meaningful sample to compute detection_rate against.
ERROR_RATE       = 0.02
_ERROR_CATEGORIES = ["schema", "business_logic", "reference", "duplicate", "time_anomaly"]


def build_dsn() -> str:
    """Build the Postgres DSN from environment variables.

    Why string-concat instead of psycopg.connect(host=..., port=...):
    - One source of truth (the DSN) that we can also paste into psql for
      manual inspection.
    - Fails loudly via KeyError if any required env var is missing — better
      than a silent default that connects to the wrong database.
    """
    return (
        f"host={os.environ['POSTGRES_HOST']} "
        f"port={os.environ['POSTGRES_PORT']} "
        f"dbname={os.environ['POSTGRES_DB']} "
        f"user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']}"
    )


def wait_for_postgres(dsn: str) -> None:
    """Block until Postgres accepts a connection.

    docker-compose's `depends_on: condition: service_healthy` already gates
    the app on Postgres' healthcheck, but that check only confirms the
    process is up — not that it's ready to accept queries on a fresh init.
    A small retry loop is cheaper than debugging a flaky first start.
    """
    while True:
        try:
            with psycopg.connect(dsn) as conn:
                conn.execute("SELECT 1")
            print("[startup] Postgres connection established.")
            return
        except Exception as exc:
            print(f"[startup] Waiting for Postgres... ({exc})")
            time.sleep(2)


def _is_first_run(conn) -> bool:
    """True iff the events table is empty.

    Used to decide whether to seed the historical backlog. The check is on
    `events`, not on a separate "did we seed?" flag, because the only thing
    that actually matters is whether there's data to query — flags drift
    from reality, row counts don't.
    """
    return conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0


def _process_events(conn, raw_events: list[dict], seen_ids: set[str]) -> dict:
    """Inject errors, validate, charge, and persist a list of events.

    The two-pass structure (build `items`, then iterate) exists for one
    reason: the `duplicate` injection has to produce two rows from one
    source event. Doing that inline with the validator/charge logic
    tangled three concerns together; splitting it out keeps each loop
    single-purpose.
    """
    events_generated = errors_injected = errors_detected = 0

    # --- Pass 1: apply error injection, expand duplicates into two items.
    items: list[tuple[dict, int]] = []
    for event in raw_events:
        if random.random() < ERROR_RATE:
            category = random.choice(_ERROR_CATEGORIES)
            event = inject_error(event, category)
            if category == "duplicate":
                # Duplicate is special: the *first* arrival is legitimate,
                # the *second* is the injected error. We emit both so the
                # validator's seen_ids set actually has something to detect.
                items.append((event, 0))   # first occurrence: not an injection
                items.append((event, 1))   # second occurrence: counts as injected
                continue
            items.append((event, 1))
        else:
            items.append((event, 0))

    # --- Pass 2: validate → persist clean events → charge → record errors.
    for event, injected_count in items:
        events_generated += 1
        errors_injected  += injected_count

        validation_errors = validate_event(event, seen_ids=seen_ids)
        if validation_errors:
            # Errors get the original payload preserved as JSONB so we can
            # forensically reconstruct what happened without joining tables.
            errors_detected += len(validation_errors)
            for err in validation_errors:
                conn.execute(
                    "INSERT INTO errors (event_id, category, details, raw_payload)"
                    " VALUES (%s, %s, %s, %s)",
                    (event.get("event_id"), err.category, err.details, Jsonb(event)),
                )
            continue

        # Only clean events reach here. Mark id as seen *before* the insert
        # so subsequent in-batch duplicates fail the validator check above.
        seen_ids.add(event["event_id"])

        # ON CONFLICT DO NOTHING is the across-batch safety net: if the
        # same event_id arrives in a later run (network retry, replayed
        # webhook), the insert is silently absorbed. Without it, one
        # duplicate would abort the whole transaction.
        conn.execute(
            "INSERT INTO events"
            " (event_id, merchant_id, warehouse_id, event_type, event_timestamp, raw_payload)"
            " VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (event_id) DO NOTHING",
            (event["event_id"], event["merchant_id"], event["warehouse_id"],
             event["event_type"], event["timestamp"], Jsonb(event)),
        )

        # Charge calculation is wrapped in try/except because a malformed
        # rate card should *log and skip*, not crash the entire batch.
        # The event row is still in `events` — analysts can spot missing
        # charges with a left join.
        try:
            amount, version = calculate_charge(event)
            conn.execute(
                "INSERT INTO charges (event_id, merchant_id, amount, rate_card_version)"
                " VALUES (%s, %s, %s, %s)",
                (event["event_id"], event["merchant_id"], amount, version),
            )
        except Exception as exc:
            print(f"[charge] {event['event_id']}: {exc}")

    return {"events_generated": events_generated,
            "errors_injected":  errors_injected,
            "errors_detected":  errors_detected}


def _write_audit(conn, stats: dict) -> None:
    """Compute detection_rate once per batch and persist to audit_summary.

    Detection rate is the headline data-quality KPI. Writing it once per
    batch (rather than per event) means Power BI reads a tiny pre-aggregated
    table instead of running a window function over millions of rows.

    Edge case: a batch with zero injected errors has no denominator. We
    return 100.0 in that case — a "nothing to detect, nothing missed"
    semantics that doesn't pollute the time-series with NaNs.
    """
    rate = round(stats["errors_detected"] / stats["errors_injected"] * 100, 2) \
           if stats["errors_injected"] else 100.0
    conn.execute(
        "INSERT INTO audit_summary"
        " (events_generated, errors_injected, errors_detected, detection_rate)"
        " VALUES (%s, %s, %s, %s)",
        (stats["events_generated"], stats["errors_injected"], stats["errors_detected"], rate),
    )
    stats["detection_rate"] = rate


def seed_backlog(conn) -> None:
    """First-run-only: synthesise 3 months of history so the dashboard
    shows a useful chart immediately after `docker compose up`."""
    print("[backlog] Generating 3-month historical dataset (1 800 events)…")
    backlog = generate_backlog(months=3)

    # Backlog uses a fresh seen_ids set — the in-memory dedup is per-run.
    # Cross-run dedup is the PRIMARY KEY's job (see ON CONFLICT above).
    seen: set[str] = set()
    stats = _process_events(conn, backlog, seen)
    _write_audit(conn, stats)
    print(
        f"[backlog] Seeded {stats['events_generated']} events | "
        f"{stats['errors_injected']} injected | "
        f"{stats['errors_detected']} detected | "
        f"rate {stats['detection_rate']:.1f}%"
    )


def run_hourly(conn, seen_ids: set[str]) -> dict:
    """Process one hour's worth of new events.

    A no-op batch (Poisson happened to roll zero) skips the audit insert —
    we don't want a row in audit_summary representing "nothing happened",
    that would dilute the time-series average.
    """
    batch = hourly_batch()
    if not batch:
        return {"events_generated": 0, "errors_injected": 0,
                "errors_detected": 0, "detection_rate": 100.0}
    stats = _process_events(conn, batch, seen_ids)
    _write_audit(conn, stats)
    return stats


if __name__ == "__main__":
    dsn = build_dsn()
    wait_for_postgres(dsn)

    # Backlog seeding gets its own connection-with block so we can commit
    # and close cleanly before entering the long-running hourly loop.
    with psycopg.connect(dsn) as conn:
        if _is_first_run(conn):
            seed_backlog(conn)
            conn.commit()

    print("[portbill] Pipeline live — hourly updates running.")

    # In-memory dedup carried across hourly batches but reset on container
    # restart. That's intentional: cold-start dedup is the PRIMARY KEY's job.
    # Holding seen_ids forever would leak memory for no benefit.
    seen_ids: set[str] = set()

    while True:
        # Connection-per-batch, not pooled: the loop sleeps for an hour
        # between runs, so a long-lived connection would just rot. Reconnecting
        # each hour also makes us resilient to a Postgres restart overnight
        # without any extra retry code.
        with psycopg.connect(dsn) as conn:
            stats = run_hourly(conn, seen_ids)
            conn.commit()
        if stats["events_generated"]:
            print(
                f"[hourly] generated={stats['events_generated']} "
                f"injected={stats['errors_injected']} "
                f"detected={stats['errors_detected']} "
                f"rate={stats['detection_rate']:.1f}%"
            )
        time.sleep(3600)
