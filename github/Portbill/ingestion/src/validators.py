from dataclasses import dataclass
from datetime import datetime, timezone, timedelta

from generator.src.generator import MERCHANTS, REQUIRED_FIELDS

_MAX_FUTURE_SECONDS = 60


@dataclass
class ValidationError:
    category: str  # schema | business_logic | reference | duplicate | time_anomaly
    details: str


def validate_event(event: dict, seen_ids: set[str] | None = None) -> list[ValidationError]:
    """Return a list of validation errors. Empty list means the event is clean."""
    errors: list[ValidationError] = []

    # schema: required fields must be present
    missing = REQUIRED_FIELDS - event.keys()
    if missing:
        errors.append(ValidationError("schema", f"Missing fields: {sorted(missing)}"))
        return errors  # remaining checks need these fields present

    # duplicate: same event_id already processed in this run
    if seen_ids is not None and event["event_id"] in seen_ids:
        errors.append(ValidationError("duplicate", f"event_id already seen: {event['event_id']}"))

    # business_logic: quantity must be positive
    if event["quantity"] <= 0:
        errors.append(ValidationError("business_logic", f"quantity must be > 0, got {event['quantity']}"))

    # reference: merchant must map to an existing rate card
    if event["merchant_id"] not in MERCHANTS:
        errors.append(ValidationError("reference", f"No rate card for merchant '{event['merchant_id']}'"))

    # time_anomaly: timestamp must not be meaningfully in the future
    try:
        ts = datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00"))
        if ts > datetime.now(timezone.utc) + timedelta(seconds=_MAX_FUTURE_SECONDS):
            errors.append(ValidationError("time_anomaly", f"Timestamp is in the future: {event['timestamp']}"))
    except ValueError:
        errors.append(ValidationError("schema", f"Invalid timestamp format: {event['timestamp']}"))

    return errors
