"""Parse the raw candle rows the exchange returns.

The exchange sends a list of lists, with numbers as strings. This module turns
that into one frame with a fixed schema, and refuses anything malformed. It
makes no network call, so the tests need no network.
"""
from __future__ import annotations

import pandas as pd

RAW_COLUMNS = ["open_time", "open", "high", "low", "close", "volume", "trades"]

_SOURCE_FIELDS = 12
_PRICE_COLUMNS = ["open", "high", "low", "close", "volume"]


def parse_klines(rows: list[list]) -> pd.DataFrame:
    """Turn the exchange rows into the agreed frame.

    Args:
        rows: the list the exchange returns, newest or oldest first.

    Returns:
        One row per hour, sorted by time, with no repeated hour.

    Raises:
        ValueError: the list is empty, a row is the wrong width, or a candle
            reports a high under its low.
    """
    if not rows:
        raise ValueError("the exchange returned no candles")

    for row in rows:
        if len(row) != _SOURCE_FIELDS:
            raise ValueError(f"a row holds {len(row)} fields, not {_SOURCE_FIELDS}")

    frame = pd.DataFrame(rows).iloc[:, [0, 1, 2, 3, 4, 5, 8]]
    frame.columns = RAW_COLUMNS

    frame["open_time"] = pd.to_datetime(frame.open_time, unit="ms", utc=True).astype(
        "datetime64[ms, UTC]")
    frame[_PRICE_COLUMNS] = frame[_PRICE_COLUMNS].astype("float64")
    frame["trades"] = frame.trades.astype("int64")

    broken = frame.high < frame.low
    if broken.any():
        raise ValueError(f"{int(broken.sum())} candles report a high under the low")

    frame = frame.drop_duplicates(subset="open_time", keep="first")
    frame = frame.sort_values("open_time").reset_index(drop=True)
    return frame
