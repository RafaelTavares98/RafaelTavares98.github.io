"""The first test. It is written before the code it describes.

The contract of the ingestion layer: give it a raw response from the exchange,
and it returns a frame with a fixed schema, in order, with no gaps.
"""
import pandas as pd
import pytest

from btc.ingest.klines import RAW_COLUMNS, parse_klines


RAW_ROWS = [
    [1788141600000, "77640.93", "78000.00", "77392.00", "77473.99", "573.39",
     1788145199999, "44571951.93", 173143, "345.41", "26857082.32", "0"],
    [1788145200000, "77474.00", "77872.00", "77394.00", "77756.71", "278.92",
     1788148799999, "21668121.17", 118748, "152.93", "11880039.04", "0"],
]


def test_parse_returns_the_agreed_columns():
    out = parse_klines(RAW_ROWS)
    assert list(out.columns) == RAW_COLUMNS


def test_open_time_becomes_an_hourly_timestamp_in_utc():
    out = parse_klines(RAW_ROWS)
    assert str(out.open_time.dtype) == "datetime64[ms, UTC]"
    assert (out.open_time.dt.minute == 0).all()


def test_prices_become_floats():
    out = parse_klines(RAW_ROWS)
    for column in ["open", "high", "low", "close", "volume"]:
        assert out[column].dtype == "float64"


def test_rows_come_back_in_time_order():
    out = parse_klines(list(reversed(RAW_ROWS)))
    assert out.open_time.is_monotonic_increasing


def test_a_repeated_candle_is_dropped():
    out = parse_klines(RAW_ROWS + [RAW_ROWS[0]])
    assert len(out) == 2
    assert out.open_time.is_unique


def test_high_below_low_is_rejected():
    broken = [list(RAW_ROWS[0])]
    broken[0][2], broken[0][3] = "1.0", "9.0"   # high under low
    with pytest.raises(ValueError):
        parse_klines(broken)


def test_an_empty_response_is_rejected():
    with pytest.raises(ValueError):
        parse_klines([])
