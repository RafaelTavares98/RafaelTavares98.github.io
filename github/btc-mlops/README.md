# Bitcoin hourly volatility: an MLOps pipeline

The subject is deliberately small. The engineering is the product.

The pipeline pulls hourly Bitcoin candles, builds features that never read the
future, trains a challenger, promotes it only when it wins by a margin, writes
a forecast before the hour happens, and watches its own decay.

**Project page:** https://rafaeltavares98.github.io/btc-mlops.html

## What it reaches

The reference is Google's *MLOps: continuous delivery and automation pipelines
in machine learning*, which defines three levels of maturity.

| Level | What it means | Here |
| --- | --- | --- |
| 0 | Everything by hand | |
| 1 | The training pipeline is automated | |
| 2 | **CI/CD deploys the pipeline itself, not the model** | This project |

The measure is the ML Test Score, from Breck and others, Google, IEEE Big Data
2017. It scores 28 tests in four sections and takes the minimum.

**The score is 5.0**, at the top of the band the paper calls strong automated
testing and monitoring. The full rubric, line by line, is in
[`ML_TEST_SCORE.md`](ML_TEST_SCORE.md).

## The result

The model predicts the range of the coming hour, as `(high - low) / close`.

| Measure | Value |
| --- | --- |
| Mean absolute error | 0.001823 |
| Baseline error | 0.002270 |
| **Skill against the baseline** | **0.197** |
| Rows for training | 4,481 |
| Rows for testing | 1,494 |

The baseline repeats the hour that just closed, which is what a person does for
free. Skill is the share of that error the model removes. The model removes a
fifth of it.

Skill by hour of day is in `results/skill_by_hour.csv`. Two of the 24 hours
come back negative, so the model loses to the baseline in those hours. That is
the kind of finding a single average hides.

## The design

```
raw_candles  ->  features  ->  trained_model  ->  production_model
                         \                                \
                          ->  monitoring_report             ->  hourly_forecast
```

Six Dagster assets. Each one is a table or a model, not a task, so a failure
names the asset that broke.

| Asset | What it guarantees |
| --- | --- |
| `raw_candles` | The request overlaps the previous run. The warehouse drops the overlap, so a missed hour is picked up later |
| `features` | Eleven columns, none of which reads a later row |
| `trained_model` | A challenger, scored against the baseline, logged to MLflow |
| `production_model` | The gate. The challenger serves only when it cuts the error by 2% |
| `hourly_forecast` | One forecast, stored **before** the hour it describes |
| `monitoring_report` | Data drift, rolling skill, and the retraining decision |

## The five things that make it a production pipeline

1. **CI ships the pipeline, not the model.** A merge rebuilds and republishes
   the pipeline image. The model is produced by the pipeline, on a schedule.
2. **A test proves no feature reads the future.** It scrambles every row after
   one hour, recomputes, and fails if that hour's features move by a digit.
   Leakage is silent, and no other test catches it.
3. **The gate is automatic and reversible.** The registry alias moves to the
   challenger only on a win by margin. A tie keeps the champion. Rolling back
   is moving the alias back.
4. **Every forecast names its data, code and model version.** A forecast that
   cannot be traced cannot be audited.
5. **Retraining fires on drift, not on the calendar.** A schedule retrains a
   healthy model and hides a sick one.

## The stack

Everything is free and runs on one machine.

| Piece | Tool |
| --- | --- |
| Orchestration | Dagster |
| Warehouse | DuckDB |
| Tracking and registry | MLflow |
| Model | LightGBM |
| Drift | Kolmogorov-Smirnov, from SciPy |
| Service | FastAPI in Docker |
| CI/CD | GitHub Actions |
| Tests | pytest |

## The tests

56 tests, all in CI.

| File | Covers |
| --- | --- |
| `test_ingest.py` | The candle schema. A malformed candle is refused |
| `test_fetch.py` | Paging, with a fake exchange. No test touches the network |
| `test_features.py` | The feature contract, and the leakage test |
| `test_storage.py` | Idempotency. Running the same load twice writes nothing |
| `test_train.py` | The time-ordered split, the baseline, and the gate |
| `test_monitor.py` | Data drift, concept drift, and the retraining decision |
| `test_api.py` | The service contract. A bad request never reaches the model |

## The data

Binance public klines, `BTCUSDT`, hourly. No key, no account.

6,000 candles, from 2025-12-25 to 2026-08-31. Nothing is stored in this
repository, because the pipeline fetches it.

## How to run it

Python 3.12.

```bash
pip install -r requirements.txt
export PYTHONPATH=src
export MLFLOW_TRACKING_URI=sqlite:///mlflow.db

# the whole pipeline, once
python -c "
from dagster import materialize
from btc.pipeline import assets as A
materialize([A.raw_candles, A.features, A.trained_model,
             A.production_model, A.hourly_forecast, A.monitoring_report])
"

# the interface, with the lineage graph and the schedule
dagster dev -m btc.pipeline.assets

# the service
uvicorn btc.serve.api:app --reload
```

The first run fetches 6,000 hours and takes about a minute. Training takes 23
seconds on eight cores.

## The files

| Path | What it holds |
| --- | --- |
| `src/btc/ingest/` | The exchange call, and the candle parser |
| `src/btc/features/` | The eleven features and the target |
| `src/btc/train/` | Training, scoring, and the promotion gate |
| `src/btc/monitor/` | Drift, rolling skill, and the retraining decision |
| `src/btc/storage/` | The DuckDB warehouse |
| `src/btc/pipeline/` | The six Dagster assets and the schedule |
| `src/btc/serve/` | The FastAPI service |
| `ML_TEST_SCORE.md` | The 28 tests, scored line by line |

The CI workflow sits at the repository root, in
`.github/workflows/btc-mlops-ci.yml`, because GitHub Actions reads workflows
only from there.

## The references

| Work | What it gives |
| --- | --- |
| Google Cloud, *MLOps: continuous delivery and automation pipelines in machine learning* | The three levels of maturity, and what level 2 requires |
| Breck, Cai, Nielsen, Salib and Sculley, *The ML Test Score*, IEEE Big Data, 2017 | The 28 tests and the scoring rule |
| Sculley and others, *Hidden Technical Debt in Machine Learning Systems*, NeurIPS, 2015 | Why the code around the model is where the debt hides |
