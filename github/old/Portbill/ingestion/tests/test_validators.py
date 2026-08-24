from datetime import datetime, timezone, timedelta

from generator.src.generator import generate_event
from ingestion.src.validators import validate_event


def test_schema_error_on_missing_field():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    event.pop("quantity")
    errors = validate_event(event)
    assert any(e.category == "schema" for e in errors)


def test_business_logic_error_on_nonpositive_quantity():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    event["quantity"] = -1
    errors = validate_event(event)
    assert any(e.category == "business_logic" for e in errors)


def test_reference_error_on_unknown_merchant():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    event["merchant_id"] = "NO-SUCH-MERCHANT"
    errors = validate_event(event)
    assert any(e.category == "reference" for e in errors)


def test_duplicate_error_when_event_id_already_seen():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    seen = {event["event_id"]}
    errors = validate_event(event, seen_ids=seen)
    assert any(e.category == "duplicate" for e in errors)


def test_time_anomaly_on_future_timestamp():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    future = datetime.now(timezone.utc) + timedelta(days=1)
    event["timestamp"] = future.strftime("%Y-%m-%dT%H:%M:%S.") + f"{future.microsecond // 1000:03d}Z"
    errors = validate_event(event)
    assert any(e.category == "time_anomaly" for e in errors)


def test_valid_event_has_no_errors():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    assert validate_event(event) == []
