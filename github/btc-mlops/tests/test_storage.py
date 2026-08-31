"""The warehouse contract, written before the code.

The rule under test is idempotency. The scheduled job runs every hour, it
overlaps with the run before it, and it must never double count a candle.
"""
import pandas as pd
import pytest

from btc.storage.warehouse import (append_candles, latest_open_time, read_candles,
                                   write_predictions, read_predictions)
from tests.test_features import candles


@pytest.fixture
def db(tmp_path):
    return str(tmp_path / "test.duckdb")


def test_the_first_load_writes_every_row(db):
    written = append_candles(db, candles(100))
    assert written == 100
    assert len(read_candles(db)) == 100


def test_running_the_same_load_twice_changes_nothing(db):
    frame = candles(100)
    append_candles(db, frame)
    written = append_candles(db, frame)
    assert written == 0
    assert len(read_candles(db)) == 100


def test_an_overlapping_load_writes_only_the_new_hours(db):
    frame = candles(120)
    append_candles(db, frame.iloc[:100])
    written = append_candles(db, frame.iloc[80:])
    assert written == 20
    assert len(read_candles(db)) == 120


def test_the_stored_rows_stay_in_time_order(db):
    append_candles(db, candles(100))
    stored = read_candles(db)
    assert stored.open_time.is_monotonic_increasing


def test_the_latest_hour_is_reported(db):
    frame = candles(100)
    append_candles(db, frame)
    assert latest_open_time(db) == frame.open_time.max()


def test_an_empty_warehouse_reports_no_latest_hour(db):
    assert latest_open_time(db) is None


def test_predictions_are_stored_with_their_model_version(db):
    made = pd.DataFrame({
        "open_time": pd.to_datetime(["2026-01-01T00:00:00Z"]).astype("datetime64[ms, UTC]"),
        "predicted": [0.004], "model_version": ["3"], "run_id": ["abc"]})
    write_predictions(db, made)
    back = read_predictions(db)
    assert back.model_version.iloc[0] == "3"
    assert back.predicted.iloc[0] == pytest.approx(0.004)
