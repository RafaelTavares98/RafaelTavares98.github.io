from datetime import datetime, timezone
from generator.src.generator import generate_event, inject_error, REQUIRED_FIELDS, MERCHANTS


def test_generate_event_has_all_required_fields():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    assert REQUIRED_FIELDS.issubset(event.keys())


def test_generate_event_respects_merchant_and_type():
    event = generate_event("HARLOW-ELECTRONICS", "ship")
    assert event["merchant_id"] == "HARLOW-ELECTRONICS"
    assert event["event_type"] == "ship"


def test_generate_event_storage_snapshot_has_pallet_count():
    event = generate_event("ORION-HOMEGOODS", "storage_snapshot")
    assert "pallet_count" in event["metadata"]
    assert event["metadata"]["pallet_count"] >= 1


def test_generate_event_quantity_within_profile_bounds():
    # HARLOW-ELECTRONICS has qty_max=15; no generated event should exceed it
    for _ in range(30):
        event = generate_event("HARLOW-ELECTRONICS", "pick")
        assert 1 <= event["quantity"] <= 15


def test_generate_event_uom_is_american_standard():
    valid_uoms = {"ea", "cs", "plt", "lb", "pc", "unit"}
    for merchant in MERCHANTS:
        event = generate_event(merchant, "pick")
        assert event["unit_of_measure"] in valid_uoms


def test_inject_error_schema_drops_a_required_field():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    corrupted = inject_error(event, "schema")
    assert not REQUIRED_FIELDS.issubset(corrupted.keys())


def test_inject_error_business_logic_nonpositive_quantity():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    corrupted = inject_error(event, "business_logic")
    assert corrupted["quantity"] <= 0


def test_inject_error_reference_unknown_merchant():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    corrupted = inject_error(event, "reference")
    assert corrupted["merchant_id"] not in MERCHANTS


def test_inject_error_duplicate_preserves_event_id():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    original_id = event["event_id"]
    corrupted = inject_error(event, "duplicate")
    assert corrupted["event_id"] == original_id


def test_inject_error_time_anomaly_is_in_the_future():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    corrupted = inject_error(event, "time_anomaly")
    ts = datetime.fromisoformat(corrupted["timestamp"].replace("Z", "+00:00"))
    assert ts > datetime.now(timezone.utc)


def test_inject_error_does_not_mutate_original():
    event = generate_event("NORDVIK-LOGISTICS", "pick")
    original_quantity = event["quantity"]
    inject_error(event, "business_logic")
    assert event["quantity"] == original_quantity
