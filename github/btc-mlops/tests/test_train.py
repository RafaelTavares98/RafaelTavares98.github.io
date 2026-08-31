"""The training contract and the promotion gate, written before the code.

Two ideas are under test. A split that respects time, and a gate that only
promotes a challenger that beats the champion by a stated margin.
"""
import numpy as np
import pandas as pd
import pytest

from btc.features.build import FEATURE_COLUMNS, TARGET
from btc.train.pipeline import (MIN_IMPROVEMENT, baseline_prediction, promote,
                                split_by_time, train_model)
from tests.test_features import candles
from btc.features.build import build_features


def frame(n: int = 900) -> pd.DataFrame:
    return build_features(candles(n, seed=7))


# ---------------------------------------------------------------- the split

def test_the_split_is_ordered_in_time():
    train, test = split_by_time(frame(), test_fraction=0.25)
    assert train.open_time.max() < test.open_time.min()


def test_the_split_keeps_every_row():
    data = frame()
    train, test = split_by_time(data, test_fraction=0.25)
    assert len(train) + len(test) == len(data)


def test_the_test_share_is_respected():
    data = frame()
    _, test = split_by_time(data, test_fraction=0.25)
    assert abs(len(test) / len(data) - 0.25) < 0.01


def test_a_random_split_is_impossible():
    """Calling twice returns the same split, because time decides it."""
    data = frame()
    first, _ = split_by_time(data, test_fraction=0.25)
    second, _ = split_by_time(data, test_fraction=0.25)
    pd.testing.assert_frame_equal(first, second)


# ------------------------------------------------------------- the baseline

def test_the_baseline_repeats_the_current_range():
    data = frame()
    assert np.array_equal(baseline_prediction(data), data.range_now.to_numpy())


# -------------------------------------------------------------- the training

def test_training_returns_a_model_and_its_scores():
    train, test = split_by_time(frame(), test_fraction=0.25)
    model, scores = train_model(train, test)
    assert hasattr(model, "predict")
    assert {"mae", "baseline_mae", "skill"} <= scores.keys()


def test_the_model_predicts_one_number_per_row():
    train, test = split_by_time(frame(), test_fraction=0.25)
    model, _ = train_model(train, test)
    assert model.predict(test[FEATURE_COLUMNS]).shape == (len(test),)


def test_skill_is_the_gain_over_the_baseline():
    train, test = split_by_time(frame(), test_fraction=0.25)
    _, scores = train_model(train, test)
    expected = 1 - scores["mae"] / scores["baseline_mae"]
    assert scores["skill"] == pytest.approx(expected)


def test_training_never_sees_the_target_as_a_feature():
    train, test = split_by_time(frame(), test_fraction=0.25)
    assert TARGET not in FEATURE_COLUMNS
    model, _ = train_model(train, test)
    assert list(model.feature_name_) == FEATURE_COLUMNS


# ------------------------------------------------------------------ the gate

def test_a_clearly_better_challenger_is_promoted():
    assert promote(champion_mae=0.010, challenger_mae=0.008) is True


def test_a_worse_challenger_is_refused():
    assert promote(champion_mae=0.010, challenger_mae=0.012) is False


def test_a_tie_keeps_the_champion():
    assert promote(champion_mae=0.010, challenger_mae=0.010) is False


def test_a_gain_under_the_margin_keeps_the_champion():
    barely = 0.010 * (1 - MIN_IMPROVEMENT / 2)
    assert promote(champion_mae=0.010, challenger_mae=barely) is False


def test_the_first_model_is_always_promoted():
    assert promote(champion_mae=None, challenger_mae=0.05) is True
