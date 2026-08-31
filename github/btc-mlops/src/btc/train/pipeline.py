"""Train one model, score it against the baseline, and decide promotion.

Three rules hold this module together.

1. The split follows time. A random split on a time series trains on the
   future and tests on the past.
2. The score that counts is skill against a baseline, not the raw error. The
   baseline repeats the current hour, which is what a person does for free.
3. A challenger replaces the champion only when it wins by a stated margin.
   A win of one digit is noise.
"""
from __future__ import annotations

import lightgbm as lgb
import numpy as np
import pandas as pd

from btc.features.build import FEATURE_COLUMNS, TARGET

MIN_IMPROVEMENT = 0.02   # the challenger has to cut the error by 2%
SEED = 42

MODEL_PARAMS = dict(
    objective="l1",
    n_estimators=400,
    learning_rate=0.05,
    num_leaves=31,
    min_child_samples=40,
    subsample=0.8,
    subsample_freq=1,
    colsample_bytree=0.8,
    n_jobs=-1,
    verbose=-1,
    random_state=SEED,
)


def split_by_time(features: pd.DataFrame, test_fraction: float = 0.25
                  ) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Cut the frame in two, with every training row older than every test row."""
    ordered = features.sort_values("open_time").reset_index(drop=True)
    cut = len(ordered) - int(round(len(ordered) * test_fraction))
    return ordered.iloc[:cut].copy(), ordered.iloc[cut:].reset_index(drop=True)


def baseline_prediction(features: pd.DataFrame) -> np.ndarray:
    """The free forecast: the coming hour looks like the hour that just closed."""
    return features["range_now"].to_numpy()


def train_model(train: pd.DataFrame, test: pd.DataFrame
                ) -> tuple[lgb.LGBMRegressor, dict[str, float]]:
    """Fit on the older rows, score on the newer ones.

    Returns:
        The fitted model, and a dictionary holding `mae`, `baseline_mae` and
        `skill`. Skill is the share of the baseline error the model removes.
    """
    model = lgb.LGBMRegressor(**MODEL_PARAMS)
    model.fit(train[FEATURE_COLUMNS], train[TARGET])

    truth = test[TARGET].to_numpy()
    mae = float(np.mean(np.abs(model.predict(test[FEATURE_COLUMNS]) - truth)))
    baseline_mae = float(np.mean(np.abs(baseline_prediction(test) - truth)))

    return model, {"mae": mae,
                   "baseline_mae": baseline_mae,
                   "skill": 1 - mae / baseline_mae,
                   "rows_train": float(len(train)),
                   "rows_test": float(len(test))}


def promote(champion_mae: float | None, challenger_mae: float) -> bool:
    """Decide whether the challenger replaces the champion.

    Args:
        champion_mae: the error of the model now in production, or None when
            no model is serving yet.
        challenger_mae: the error of the model that just trained.

    Returns:
        True when the challenger wins by at least `MIN_IMPROVEMENT`.
    """
    if champion_mae is None:
        return True
    return challenger_mae < champion_mae * (1 - MIN_IMPROVEMENT)
