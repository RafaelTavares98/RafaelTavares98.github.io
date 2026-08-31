"""The feature contract, written before the code.

The test that matters here is the last one. It proves that no feature reads a
row that arrives after the row it describes. A leak is silent, it inflates
every metric, and no other test catches it.
"""
import numpy as np
import pandas as pd
import pytest

from btc.features.build import FEATURE_COLUMNS, TARGET, build_features


def candles(n: int = 400, seed: int = 0) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    close = 70_000 * np.exp(np.cumsum(rng.normal(0, 0.004, n)))
    high = close * (1 + abs(rng.normal(0, 0.002, n)))
    low = close * (1 - abs(rng.normal(0, 0.002, n)))
    return pd.DataFrame({
        "open_time": pd.date_range("2026-01-01", periods=n, freq="h", tz="UTC"
                                   ).astype("datetime64[ms, UTC]"),
        "open": close, "high": high, "low": low, "close": close,
        "volume": rng.lognormal(5, 1, n), "trades": rng.integers(1, 5000, n)})


def test_it_returns_the_agreed_columns():
    out = build_features(candles())
    assert list(out.columns) == ["open_time", *FEATURE_COLUMNS, TARGET]


def test_the_target_is_the_volatility_of_the_next_hour():
    frame = candles()
    out = build_features(frame)
    row = out.iloc[0]
    following = frame[frame.open_time > row.open_time].iloc[0]
    expected = (following.high - following.low) / following.close
    assert row[TARGET] == pytest.approx(expected)


def test_the_last_row_has_no_target_and_is_dropped():
    frame = candles()
    out = build_features(frame)
    assert out.open_time.max() < frame.open_time.max()
    assert out[TARGET].notna().all()


def test_rows_without_a_full_window_are_dropped():
    out = build_features(candles(60))
    assert out[FEATURE_COLUMNS].notna().all().all()


def test_a_short_frame_is_rejected():
    with pytest.raises(ValueError):
        build_features(candles(5))


def test_no_feature_reads_the_future():
    """Change everything after one hour. The features of that hour must hold."""
    frame = candles()
    cut = 200
    tampered = frame.copy()
    rng = np.random.default_rng(99)
    for column in ["open", "high", "low", "close", "volume"]:
        tampered.loc[cut + 1:, column] *= rng.uniform(2, 5, len(tampered) - cut - 1)

    before = build_features(frame)
    after = build_features(tampered)
    hour = frame.open_time.iloc[cut]

    row_before = before[before.open_time == hour][FEATURE_COLUMNS].to_numpy()
    row_after = after[after.open_time == hour][FEATURE_COLUMNS].to_numpy()
    assert len(row_before) == 1
    np.testing.assert_allclose(row_before, row_after, rtol=1e-12,
                               err_msg="a feature read a row from the future")
