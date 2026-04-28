import os
import random
import time

import psycopg
from psycopg.types.json import Jsonb

from src.generator import generate_backlog, hourly_batch, inject_error
from src.lua_runner import calculate_charge
from src.validators import validate_event

ERROR_RATE       = 0.02
_ERROR_CATEGORIES = ["schema", "business_logic", "reference", "duplicate", "time_anomaly"]


def build_dsn() -> str:
    return (
        f"host={os.environ['POSTGRES_HOST']} "
        f"port={os.environ['POSTGRES_PORT']} "
        f"dbname={os.environ['POSTGRES_DB']} "
        f"user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']}"
    )


def wait_for_postgres(dsn: str) -> None:
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
    return conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0


def _process_events(conn, raw_events: list[dict], seen_ids: set[str]) -> dict:
    """Inject errors, validate, charge, and persist a list of events."""
    events_generated = errors_injected = errors_detected = 0

    items: list[tuple[dict, int]] = []
    for event in raw_events:
        if random.random() < ERROR_RATE:
            category = random.choice(_ERROR_CATEGORIES)
            event = inject_error(event, category)
            if category == "duplicate":
                items.append((event, 0))   # first occurrence passes
                items.append((event, 1))   # second is the injected duplicate
                continue
            items.append((event, 1))
        else:
            items.append((event, 0))

    for event, injected_count in items:
        events_generated += 1
        errors_injected  += injected_count

        validation_errors = validate_event(event, seen_ids=seen_ids)
        if validation_errors:
            errors_detected += len(validation_errors)
            for err in validation_errors:
                conn.execute(
                    "INSERT INTO errors (event_id, category, details, raw_payload)"
                    " VALUES (%s, %s, %s, %s)",
                    (event.get("event_id"), err.category, err.details, Jsonb(event)),
                )
            continue

        seen_ids.add(event["event_id"])

        conn.execute(
            "INSERT INTO events"
            " (event_id, merchant_id, warehouse_id, event_type, event_timestamp, raw_payload)"
            " VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (event_id) DO NOTHING",
            (event["event_id"], event["merchant_id"], event["warehouse_id"],
             event["event_type"], event["timestamp"], Jsonb(event)),
        )

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
    print("[backlog] Generating 3-month historical dataset (1 800 events)…")
    backlog = generate_backlog(months=3)
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

    with psycopg.connect(dsn) as conn:
        if _is_first_run(conn):
            seed_backlog(conn)
            conn.commit()

    print("[portbill] Pipeline live — hourly updates running.")
    seen_ids: set[str] = set()

    while True:
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
