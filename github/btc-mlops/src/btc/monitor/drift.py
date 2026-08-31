"""Watch the two ways a model decays, and decide when to retrain.

Data drift asks whether the features still look like the ones the model
learned on. The test is Kolmogorov-Smirnov, one column at a time.

Concept drift asks whether the model still earns its place. The measure is
rolling skill against the baseline, on hours whose truth has arrived.

Retraining fires on a threshold, never on the calendar. A schedule retrains a
healthy model and hides a sick one.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from scipy import stats

DRIFT_THRESHOLD = 0.30   # a third of the columns moved
SKILL_FLOOR = 0.0        # at zero the model ties the free baseline
P_VALUE = 0.01


def data_drift(reference: pd.DataFrame, current: pd.DataFrame) -> dict:
    """Compare two windows of features, one column at a time.

    Args:
        reference: the window the live model trained on.
        current: the window that arrived since.

    Returns:
        The share of columns that moved, the verdict, and the p-value of every
        column.
    """
    by_column = {}
    for column in reference.columns:
        left = reference[column].to_numpy(dtype="float64")
        right = current[column].to_numpy(dtype="float64")
        by_column[column] = float(stats.ks_2samp(left, right).pvalue)

    drifted = [c for c, p in by_column.items() if p < P_VALUE]
    share = len(drifted) / len(by_column)
    return {"share_drifted": share,
            "drift_detected": share > DRIFT_THRESHOLD,
            "drifted_columns": drifted,
            "by_column": by_column}


def rolling_skill(truth: np.ndarray, predicted: np.ndarray,
                  baseline: np.ndarray) -> float:
    """The share of the baseline error the model removes, on resolved hours.

    Returns:
        One when the model is perfect, zero when it ties the baseline, and a
        negative number when it loses to it.
    """
    model_error = float(np.mean(np.abs(np.asarray(predicted) - np.asarray(truth))))
    baseline_error = float(np.mean(np.abs(np.asarray(baseline) - np.asarray(truth))))
    if baseline_error == 0:
        return 0.0
    return 1 - model_error / baseline_error


def retrain_needed(share_drifted: float, skill: float, explain: bool = False):
    """Decide whether the pipeline retrains now.

    Args:
        share_drifted: the share of feature columns that moved.
        skill: the rolling skill on hours whose truth has arrived.
        explain: return the reason beside the decision.

    Returns:
        The decision, and the reason when `explain` is true.
    """
    if share_drifted > DRIFT_THRESHOLD:
        return (True, "data drift") if explain else True
    if skill < SKILL_FLOOR:
        return (True, "skill floor") if explain else True
    return (False, "healthy") if explain else False
