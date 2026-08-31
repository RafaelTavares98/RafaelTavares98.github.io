"""The prediction service.

It loads the model the registry marks as champion, and it says which version
answered. A forecast that cannot name its model version is not traceable, and
an untraceable forecast cannot be audited later.
"""
import os
from contextlib import asynccontextmanager

import mlflow
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from btc.features.build import FEATURE_COLUMNS

TRACKING = os.environ.get("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db")
MODEL_NAME = "btc-hourly-volatility"

_state: dict = {"model": None, "version": None}


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Load the champion at start. A missing registry leaves the service up
    and unhealthy, which is easier to diagnose than a crash loop."""
    try:
        load_champion()
    except Exception:
        _state["model"] = None
    yield


app = FastAPI(title="BTC hourly volatility", version="0.1.0", lifespan=lifespan)


class Candle(BaseModel):
    """The eleven features one hour produces."""
    range_now: float = Field(ge=0)
    range_mean_3: float = Field(ge=0)
    range_mean_12: float = Field(ge=0)
    range_mean_24: float = Field(ge=0)
    return_abs_mean_3: float = Field(ge=0)
    return_abs_mean_12: float = Field(ge=0)
    return_abs_mean_24: float = Field(ge=0)
    return_1h: float
    volume_ratio_24: float = Field(ge=0)
    trades_ratio_24: float = Field(ge=0)
    hour_of_day: float = Field(ge=0, le=23)


class Forecast(BaseModel):
    predicted_range: float
    model_version: str


def load_champion() -> None:
    """Read the champion from the registry and hold it in memory."""
    mlflow.set_tracking_uri(TRACKING)
    client = mlflow.MlflowClient()
    version = client.get_model_version_by_alias(MODEL_NAME, "champion")
    _state["model"] = mlflow.pyfunc.load_model(f"models:/{MODEL_NAME}@champion")
    _state["version"] = version.version


@app.get("/health")
def health() -> dict:
    """Report whether a model is loaded, and which version it is."""
    return {"status": "ok" if _state["model"] else "no model",
            "model_version": _state["version"]}


@app.post("/predict", response_model=Forecast)
def predict(candle: Candle) -> Forecast:
    """Return the volatility the coming hour is expected to carry."""
    if _state["model"] is None:
        raise HTTPException(status_code=503, detail="no champion in the registry")
    frame = pd.DataFrame([candle.model_dump()])[FEATURE_COLUMNS]
    return Forecast(predicted_range=float(_state["model"].predict(frame)[0]),
                    model_version=str(_state["version"]))


@app.post("/reload")
def reload_model() -> dict:
    """Pick up a new champion without a restart."""
    load_champion()
    return {"model_version": _state["version"]}
