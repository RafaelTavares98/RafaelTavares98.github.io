"""Build the model-ready frame from hourly candles.

Every feature reads the current row and the rows before it. Nothing reads a
later row. `tests/test_features.py` proves that on every commit.

The target is the volatility of the **next** hour, so the frame answers the
question the model is asked: how wide will the coming hour be?
"""
from __future__ import annotations

import numpy as np
import pandas as pd

WINDOWS = (3, 12, 24)
MIN_ROWS = 50

FEATURE_COLUMNS = [
    "range_now",
    *[f"range_mean_{w}" for w in WINDOWS],
    *[f"return_abs_mean_{w}" for w in WINDOWS],
    "return_1h",
    "volume_ratio_24",
    "trades_ratio_24",
    "hour_of_day",
]
TARGET = "range_next"


def build_features(candles: pd.DataFrame) -> pd.DataFrame:
    """Turn candles into one row per hour, with features and a target.

    Args:
        candles: hourly candles, sorted, as `parse_klines` returns them.

    Returns:
        The rows that carry a full window and a known target.

    Raises:
        ValueError: the frame holds fewer rows than one window needs.
    """
    if len(candles) < MIN_ROWS:
        raise ValueError(f"{len(candles)} rows is under the {MIN_ROWS} a window needs")

    frame = candles.sort_values("open_time").reset_index(drop=True)
    out = pd.DataFrame({"open_time": frame.open_time})

    hourly_range = (frame.high - frame.low) / frame.close
    log_return = np.log(frame.close).diff()

    # The current hour is closed, so reading it is not a leak.
    out["range_now"] = hourly_range
    out["return_1h"] = log_return

    for window in WINDOWS:
        out[f"range_mean_{window}"] = hourly_range.rolling(window).mean()
        out[f"return_abs_mean_{window}"] = log_return.abs().rolling(window).mean()

    out["volume_ratio_24"] = frame.volume / frame.volume.rolling(24).mean()
    out["trades_ratio_24"] = frame.trades / frame.trades.rolling(24).mean()
    out["hour_of_day"] = frame.open_time.dt.hour.astype("float64")

    # The only forward-looking column, and it is the label.
    out[TARGET] = hourly_range.shift(-1)

    out = out[["open_time", *FEATURE_COLUMNS, TARGET]]
    return out.dropna().reset_index(drop=True)
