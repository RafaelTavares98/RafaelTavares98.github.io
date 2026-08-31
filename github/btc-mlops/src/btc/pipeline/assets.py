"""The pipeline, as Dagster assets.

Each asset is a table or a model, not a task. Dagster then draws the lineage
from the raw candle to the served forecast, and a failure names the asset that
broke rather than the step number.

The five assets:

    raw_candles  ->  features  ->  trained_model  ->  production_model
                                \\
                                 ->  hourly_forecast
                                 ->  monitoring_report
"""
import os

import mlflow
import pandas as pd
from dagster import (AssetExecutionContext, Definitions, MetadataValue,
                     ScheduleDefinition, asset, define_asset_job)

from btc.features.build import FEATURE_COLUMNS, TARGET, build_features
from btc.ingest.fetch import fetch_candles
from btc.monitor.drift import data_drift, retrain_needed, rolling_skill
from btc.storage.warehouse import (append_candles, latest_open_time,
                                   read_candles, write_predictions)
from btc.train.pipeline import (baseline_prediction, promote, split_by_time,
                                train_model)

WAREHOUSE = os.environ.get("BTC_WAREHOUSE", "warehouse.duckdb")
TRACKING = os.environ.get("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db")
MODEL_NAME = "btc-hourly-volatility"
BACKFILL_HOURS = int(os.environ.get("BTC_BACKFILL_HOURS", "6000"))


@asset(description="Hourly candles, appended without duplicates.")
def raw_candles(context: AssetExecutionContext) -> pd.DataFrame:
    """Fetch and store. The request overlaps the last run, and the warehouse
    drops the overlap, so a missed hour is picked up by the run after it."""
    known = latest_open_time(WAREHOUSE)
    hours = BACKFILL_HOURS if known is None else 200
    fetched = fetch_candles(hours=hours)
    written = append_candles(WAREHOUSE, fetched)

    stored = read_candles(WAREHOUSE)
    context.add_output_metadata({
        "rows_fetched": len(fetched),
        "rows_written": written,
        "rows_stored": len(stored),
        "latest_hour": MetadataValue.text(str(stored.open_time.max())),
    })
    return stored


@asset(description="Model-ready rows. No feature reads a later row.")
def features(context: AssetExecutionContext, raw_candles: pd.DataFrame) -> pd.DataFrame:
    frame = build_features(raw_candles)
    context.add_output_metadata({
        "rows": len(frame),
        "features": len(FEATURE_COLUMNS),
        "target_mean": float(frame[TARGET].mean()),
        "first_hour": MetadataValue.text(str(frame.open_time.min())),
    })
    return frame


@asset(description="A challenger, trained on the older rows and scored on the newer.")
def trained_model(context: AssetExecutionContext, features: pd.DataFrame) -> dict:
    mlflow.set_tracking_uri(TRACKING)
    mlflow.set_experiment(MODEL_NAME)

    train, test = split_by_time(features, test_fraction=0.25)
    model, scores = train_model(train, test)

    with mlflow.start_run() as run:
        mlflow.log_params({"rows_train": len(train), "rows_test": len(test),
                           "features": len(FEATURE_COLUMNS)})
        mlflow.log_metrics(scores)
        mlflow.lightgbm.log_model(model, name="model",
                                  registered_model_name=MODEL_NAME)
        run_id = run.info.run_id

    context.add_output_metadata({k: float(v) for k, v in scores.items()}
                                | {"run_id": MetadataValue.text(run_id)})
    return {"run_id": run_id, **scores}


@asset(description="The gate. The challenger serves only when it wins by the margin.")
def production_model(context: AssetExecutionContext, trained_model: dict) -> dict:
    mlflow.set_tracking_uri(TRACKING)
    client = mlflow.MlflowClient()

    champion_mae = None
    champion_version = None
    try:
        current = client.get_model_version_by_alias(MODEL_NAME, "champion")
        champion_version = current.version
        champion_mae = client.get_run(current.run_id).data.metrics.get("mae")
    except Exception:
        context.log.info("no champion yet, the first model takes the alias")

    challenger = client.get_latest_versions(MODEL_NAME)[0]
    decision = promote(champion_mae, trained_model["mae"])

    if decision:
        client.set_registered_model_alias(MODEL_NAME, "champion", challenger.version)
        serving = challenger.version
    else:
        serving = champion_version

    context.add_output_metadata({
        "promoted": decision,
        "serving_version": MetadataValue.text(str(serving)),
        "champion_mae": champion_mae if champion_mae is not None else float("nan"),
        "challenger_mae": trained_model["mae"],
    })
    return {"promoted": decision, "version": str(serving)}


@asset(description="One forecast for the coming hour, written before it happens.")
def hourly_forecast(context: AssetExecutionContext, features: pd.DataFrame,
                    production_model: dict) -> pd.DataFrame:
    mlflow.set_tracking_uri(TRACKING)
    model = mlflow.pyfunc.load_model(f"models:/{MODEL_NAME}@champion")

    newest = features.iloc[[-1]]
    made = pd.DataFrame({
        "open_time": newest.open_time.values,
        "predicted": model.predict(newest[FEATURE_COLUMNS]),
        "model_version": production_model["version"],
        "run_id": context.run_id,
    })
    write_predictions(WAREHOUSE, made)

    context.add_output_metadata({"predicted": float(made.predicted.iloc[0]),
                                 "for_hour": MetadataValue.text(str(made.open_time.iloc[0]))})
    return made


@asset(description="Drift, rolling skill, and the retraining decision.")
def monitoring_report(context: AssetExecutionContext, features: pd.DataFrame,
                      production_model: dict) -> dict:
    """Compare the window the model trained on with the window that followed,
    then score the serving model on the hours whose truth has arrived."""
    window = min(len(features) // 4, 500)
    reference = features.iloc[-2 * window:-window]
    current = features.iloc[-window:]

    drift = data_drift(reference[FEATURE_COLUMNS], current[FEATURE_COLUMNS])

    mlflow.set_tracking_uri(TRACKING)
    serving = mlflow.pyfunc.load_model(f"models:/{MODEL_NAME}@champion")
    skill = rolling_skill(current[TARGET].to_numpy(),
                          serving.predict(current[FEATURE_COLUMNS]),
                          baseline_prediction(current))
    decision, reason = retrain_needed(drift["share_drifted"], skill, explain=True)

    context.add_output_metadata({
        "share_drifted": drift["share_drifted"],
        "drifted_columns": MetadataValue.text(", ".join(drift["drifted_columns"]) or "none"),
        "rolling_skill": skill,
        "retrain": decision,
        "reason": MetadataValue.text(reason),
    })
    return {"share_drifted": drift["share_drifted"], "skill": skill,
            "retrain": decision, "reason": reason}


hourly_job = define_asset_job("hourly_job", selection="*")

defs = Definitions(
    assets=[raw_candles, features, trained_model, production_model,
            hourly_forecast, monitoring_report],
    schedules=[ScheduleDefinition(job=hourly_job, cron_schedule="5 * * * *")],
)
