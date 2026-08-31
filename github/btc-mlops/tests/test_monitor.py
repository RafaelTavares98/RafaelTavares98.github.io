"""The monitoring contract, written before the code.

Two kinds of decay, and the pipeline has to tell them apart.

Data drift: the features arrive from a different distribution.
Concept drift: the features look the same, and the model is wrong anyway.
"""
import numpy as np
import pandas as pd
import pytest

from btc.monitor.drift import (DRIFT_THRESHOLD, SKILL_FLOOR, data_drift,
                               retrain_needed, rolling_skill)
from btc.features.build import FEATURE_COLUMNS, TARGET, build_features
from tests.test_features import candles


def reference():
    return build_features(candles(600, seed=1))


# ------------------------------------------------------------- data drift

def test_the_same_data_shows_no_drift():
    frame = reference()
    report = data_drift(frame[FEATURE_COLUMNS], frame[FEATURE_COLUMNS])
    assert report["share_drifted"] == pytest.approx(0.0)
    assert report["drift_detected"] is False


def test_a_shifted_distribution_is_caught():
    frame = reference()
    moved = frame[FEATURE_COLUMNS] * 5
    report = data_drift(frame[FEATURE_COLUMNS], moved)
    assert report["share_drifted"] > DRIFT_THRESHOLD
    assert report["drift_detected"] is True


def test_the_report_names_every_column():
    frame = reference()
    report = data_drift(frame[FEATURE_COLUMNS], frame[FEATURE_COLUMNS])
    assert set(report["by_column"]) == set(FEATURE_COLUMNS)


# ---------------------------------------------------------- concept drift

def test_rolling_skill_is_positive_when_the_model_beats_the_baseline():
    truth = np.array([0.010] * 50)
    predicted = np.array([0.010] * 50)
    baseline = np.array([0.020] * 50)
    assert rolling_skill(truth, predicted, baseline) == pytest.approx(1.0)


def test_rolling_skill_is_zero_when_the_model_ties_the_baseline():
    truth = np.array([0.010] * 50)
    predicted = baseline = np.array([0.015] * 50)
    assert rolling_skill(truth, predicted, baseline) == pytest.approx(0.0)


def test_rolling_skill_turns_negative_when_the_model_loses():
    truth = np.array([0.010] * 50)
    predicted = np.array([0.030] * 50)
    baseline = np.array([0.015] * 50)
    assert rolling_skill(truth, predicted, baseline) < 0


# ----------------------------------------------------------- the decision

def test_retraining_fires_on_data_drift():
    assert retrain_needed(share_drifted=0.9, skill=0.20) is True


def test_retraining_fires_when_skill_falls_through_the_floor():
    assert retrain_needed(share_drifted=0.0, skill=SKILL_FLOOR - 0.01) is True


def test_a_healthy_model_is_left_alone():
    assert retrain_needed(share_drifted=0.0, skill=0.20) is False


def test_the_reason_is_reported():
    assert retrain_needed(share_drifted=0.9, skill=0.20, explain=True)[1] == "data drift"
    assert retrain_needed(share_drifted=0.0, skill=-1, explain=True)[1] == "skill floor"
    assert retrain_needed(share_drifted=0.0, skill=0.2, explain=True)[1] == "healthy"
