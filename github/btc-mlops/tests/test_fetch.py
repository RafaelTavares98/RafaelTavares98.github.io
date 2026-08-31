"""The fetch contract. The transport is faked, so no test touches the network."""
import pandas as pd
import pytest

from btc.ingest.fetch import PAGE, fetch_candles


def fake_exchange(total: int = 2500):
    """Serve candles the way the exchange does: newest page first, paging back."""
    base = 1_700_000_000_000
    all_rows = [[base + i * 3_600_000, "1", "2", "0.5", "1.5", "10",
                 base + (i + 1) * 3_600_000 - 1, "15", 100, "5", "7", "0"]
                for i in range(total)]

    def transport(params: dict) -> list[list]:
        end = params.get("endTime")
        window = [r for r in all_rows if end is None or r[0] <= end]
        return window[-params["limit"]:]

    return transport


def test_one_page_is_enough_for_a_small_request():
    frame = fetch_candles(hours=10, transport=fake_exchange())
    assert len(frame) == 10


def test_a_large_request_pages_backwards():
    frame = fetch_candles(hours=2500, transport=fake_exchange())
    assert len(frame) == 2500
    assert frame.open_time.is_monotonic_increasing


def test_the_page_size_is_respected():
    seen = []
    inner = fake_exchange()

    def watched(params):
        seen.append(params["limit"])
        return inner(params)

    fetch_candles(hours=2500, transport=watched)
    assert max(seen) <= PAGE


def test_an_exchange_that_runs_out_stops_the_loop():
    frame = fetch_candles(hours=5000, transport=fake_exchange(total=120))
    assert len(frame) == 120


def test_an_exchange_that_returns_nothing_is_rejected():
    with pytest.raises(ValueError):
        fetch_candles(hours=10, transport=lambda params: [])
