"""The warehouse, on DuckDB.

The scheduled job overlaps with the run before it on purpose, so that a missed
hour is picked up later. That only works when writing is idempotent, which is
what `append_candles` guarantees and what the tests prove.
"""
from __future__ import annotations

import duckdb
import pandas as pd

CANDLES = """
CREATE TABLE IF NOT EXISTS candles (
    open_time TIMESTAMPTZ PRIMARY KEY,
    open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE,
    volume DOUBLE, trades BIGINT,
    loaded_at TIMESTAMPTZ DEFAULT current_timestamp
)"""

PREDICTIONS = """
CREATE TABLE IF NOT EXISTS predictions (
    open_time TIMESTAMPTZ,
    predicted DOUBLE,
    model_version VARCHAR,
    run_id VARCHAR,
    made_at TIMESTAMPTZ DEFAULT current_timestamp,
    PRIMARY KEY (open_time, model_version)
)"""


def _connect(path: str) -> duckdb.DuckDBPyConnection:
    con = duckdb.connect(path)
    con.execute(CANDLES)
    con.execute(PREDICTIONS)
    return con


def append_candles(path: str, frame: pd.DataFrame) -> int:
    """Write the candles the warehouse does not hold yet.

    Returns:
        The number of rows written. Zero means every hour was already there.
    """
    con = _connect(path)
    try:
        con.register("incoming", frame)
        before = con.execute("SELECT count(*) FROM candles").fetchone()[0]
        con.execute("""
            INSERT INTO candles (open_time, open, high, low, close, volume, trades)
            SELECT i.open_time, i.open, i.high, i.low, i.close, i.volume, i.trades
            FROM incoming i
            WHERE NOT EXISTS (SELECT 1 FROM candles c WHERE c.open_time = i.open_time)
        """)
        after = con.execute("SELECT count(*) FROM candles").fetchone()[0]
        return after - before
    finally:
        con.close()


def read_candles(path: str) -> pd.DataFrame:
    """Every candle the warehouse holds, oldest first."""
    con = _connect(path)
    try:
        return con.execute("""
            SELECT open_time, open, high, low, close, volume, trades
            FROM candles ORDER BY open_time
        """).df()
    finally:
        con.close()


def latest_open_time(path: str) -> pd.Timestamp | None:
    """The newest hour stored, or None when the warehouse is empty."""
    con = _connect(path)
    try:
        value = con.execute("SELECT max(open_time) FROM candles").fetchone()[0]
        return None if value is None else pd.Timestamp(value)
    finally:
        con.close()


def write_predictions(path: str, frame: pd.DataFrame) -> int:
    """Store the forecasts, one row per hour and model version."""
    con = _connect(path)
    try:
        con.register("incoming", frame)
        con.execute("""
            INSERT OR REPLACE INTO predictions (open_time, predicted, model_version, run_id)
            SELECT open_time, predicted, model_version, run_id FROM incoming
        """)
        return len(frame)
    finally:
        con.close()


def read_predictions(path: str) -> pd.DataFrame:
    """Every forecast, with the hour it describes and the model that made it."""
    con = _connect(path)
    try:
        return con.execute("""
            SELECT open_time, predicted, model_version, run_id, made_at
            FROM predictions ORDER BY open_time
        """).df()
    finally:
        con.close()
