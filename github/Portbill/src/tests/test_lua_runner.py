import pytest
from src.lua_runner import calculate_charge

_TEST_CARD = """\
return {
  version = "TEST-v1",
  pick    = function(event) return event.quantity * 2.00 end,
  pack    = function(event) return 5.00 end,
  storage_snapshot = function(event)
    local pallets = event.metadata and event.metadata.pallet_count or 0
    return pallets * 3.00
  end,
}
"""


@pytest.fixture
def card_dir(tmp_path):
    d = tmp_path / "rate_cards"
    d.mkdir()
    (d / "TEST-MERCHANT.lua").write_text(_TEST_CARD)
    return str(d)


def _event(event_type, quantity, pallet_count=0):
    return {
        "merchant_id": "TEST-MERCHANT",
        "event_type": event_type,
        "quantity": quantity,
        "metadata": {"pallet_count": pallet_count},
    }


def test_per_unit_charge(card_dir):
    # pick: 3 units × $2.00 = $6.00
    amount, version = calculate_charge(_event("pick", 3), rate_cards_dir=card_dir)
    assert amount == 6.00
    assert version == "TEST-v1"


def test_flat_fee_charge(card_dir):
    # pack is always $5.00 regardless of quantity
    amount, _ = calculate_charge(_event("pack", 99), rate_cards_dir=card_dir)
    assert amount == 5.00


def test_nested_metadata_accessible(card_dir):
    # storage_snapshot reads pallet_count from event.metadata
    amount, _ = calculate_charge(_event("storage_snapshot", 0, pallet_count=4), rate_cards_dir=card_dir)
    assert amount == 12.00


def test_missing_rate_card_raises(card_dir):
    event = _event("pick", 1)
    event["merchant_id"] = "NO-CARD"
    with pytest.raises(Exception):
        calculate_charge(event, rate_cards_dir=card_dir)
