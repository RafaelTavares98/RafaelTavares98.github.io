"""
Event validation — the data-quality gate.

Five categories, matching the five injection categories in generator.py:
  - schema          — required field missing or timestamp unparseable
  - business_logic  — quantity ≤ 0 (an event no warehouse should ever emit)
  - reference       — merchant_id has no rate card (renamed/decommissioned)
  - duplicate       — event_id already seen this run
  - time_anomaly    — timestamp meaningfully in the future (> 60 s)

Why these five and not more:
  Each one corresponds to a real failure mode in the WMS → billing path.
  Adding more categories without a corresponding real-world failure mode
  would be theatre — the goal is to detect bugs that actually happen,
  not to maximise the count.

Why the schema check returns early:
  All the downstream checks dereference fields. If `quantity` is missing,
  `event["quantity"] <= 0` raises a KeyError that masks the real schema
  violation. Returning early surfaces the underlying bug cleanly.
"""

from dataclasses import dataclass
from datetime import datetime, timezone, timedelta

from generator.src.generator import MERCHANTS, REQUIRED_FIELDS

# 60-second tolerance accounts for legitimate clock skew between WMS and
# the pipeline host. Anything beyond that is almost certainly a bug
# (timezone confusion, manual data entry, replay of an old test fixture).
_MAX_FUTURE_SECONDS = 60


@dataclass
class ValidationError:
    """A single validation failure. Returned in a list so one event can
    accumulate multiple errors (e.g. unknown merchant *and* negative qty).
    A bare exception would force callers to handle errors one at a time;
    a list lets the pipeline log everything in a single pass."""
    category: str  # schema | business_logic | reference | duplicate | time_anomaly
    details: str


def validate_event(event: dict, seen_ids: set[str] | None = None) -> list[ValidationError]:
    """Return a list of validation errors. Empty list means the event is clean.

    seen_ids is optional so the function is testable in isolation: tests
    pass nothing; the pipeline passes a set it owns and mutates externally.
    Owning the set in the caller (not the validator) keeps this function
    pure and side-effect-free apart from the return value.
    """
    errors: list[ValidationError] = []

    # ── schema first ──────────────────────────────────────────────────
    # If required fields are missing the rest of the checks would crash
    # on KeyError. Return early with just the schema error so the caller
    # sees the root cause, not a misleading downstream symptom.
    missing = REQUIRED_FIELDS - event.keys()
    if missing:
        errors.append(ValidationError("schema", f"Missing fields: {sorted(missing)}"))
        return errors

    # ── duplicate detection (in-batch) ───────────────────────────────
    # The PRIMARY KEY on events.event_id catches duplicates *across*
    # batches. This catches them *within* a batch — same goal, different
    # failure mode. Without this check, a duplicate would flow through to
    # the INSERT, get silently absorbed by ON CONFLICT, and never be
    # logged in the errors table — invisible to detection_rate.
    if seen_ids is not None and event["event_id"] in seen_ids:
        errors.append(ValidationError("duplicate", f"event_id already seen: {event['event_id']}"))

    # ── business logic ───────────────────────────────────────────────
    # Negative or zero quantities are physically impossible: you can't
    # pick -3 units. Catching this here means the rate card's pricing
    # function never sees nonsense input.
    if event["quantity"] <= 0:
        errors.append(ValidationError("business_logic", f"quantity must be > 0, got {event['quantity']}"))

    # ── reference integrity ──────────────────────────────────────────
    # An unknown merchant_id has no rate card on disk, so calculate_charge
    # would raise FileNotFoundError. Catching it here means the failure is
    # categorised correctly ("we don't know who to bill") instead of
    # appearing as a mysterious charge crash in the logs.
    if event["merchant_id"] not in MERCHANTS:
        errors.append(ValidationError("reference", f"No rate card for merchant '{event['merchant_id']}'"))

    # ── time anomaly ─────────────────────────────────────────────────
    # An unparseable timestamp is a *schema* problem, not a time-anomaly
    # — it's the format that's wrong, not the value. Categorising it as
    # schema here keeps the dashboard's error breakdown semantically clean.
    try:
        ts = datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00"))
        if ts > datetime.now(timezone.utc) + timedelta(seconds=_MAX_FUTURE_SECONDS):
            errors.append(ValidationError("time_anomaly", f"Timestamp is in the future: {event['timestamp']}"))
    except ValueError:
        errors.append(ValidationError("schema", f"Invalid timestamp format: {event['timestamp']}"))

    return errors
