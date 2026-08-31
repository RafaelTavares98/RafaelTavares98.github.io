"""The service contract. A stub model stands in for the registry."""
import numpy as np
import pytest
from fastapi.testclient import TestClient

from btc.serve import api

VALID = {"range_now": 0.004, "range_mean_3": 0.004, "range_mean_12": 0.005,
         "range_mean_24": 0.005, "return_abs_mean_3": 0.001,
         "return_abs_mean_12": 0.001, "return_abs_mean_24": 0.001,
         "return_1h": -0.0002, "volume_ratio_24": 1.1,
         "trades_ratio_24": 0.9, "hour_of_day": 14}


class StubModel:
    def predict(self, frame):
        return np.array([0.0042] * len(frame))


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setitem(api._state, "model", StubModel())
    monkeypatch.setitem(api._state, "version", "7")
    return TestClient(api.app)


def test_health_reports_the_serving_version(client):
    body = client.get("/health").json()
    assert body == {"status": "ok", "model_version": "7"}


def test_a_valid_hour_returns_a_forecast(client):
    body = client.post("/predict", json=VALID).json()
    assert body["predicted_range"] == pytest.approx(0.0042)
    assert body["model_version"] == "7"


def test_every_forecast_names_its_model_version(client):
    assert "model_version" in client.post("/predict", json=VALID).json()


def test_a_missing_feature_is_refused(client):
    short = {k: v for k, v in VALID.items() if k != "range_now"}
    assert client.post("/predict", json=short).status_code == 422


def test_a_negative_range_is_refused(client):
    bad = VALID | {"range_now": -1}
    assert client.post("/predict", json=bad).status_code == 422


def test_an_impossible_hour_is_refused(client):
    bad = VALID | {"hour_of_day": 30}
    assert client.post("/predict", json=bad).status_code == 422


def test_the_service_refuses_to_guess_without_a_model(monkeypatch):
    monkeypatch.setitem(api._state, "model", None)
    monkeypatch.setitem(api._state, "version", None)
    response = TestClient(api.app).post("/predict", json=VALID)
    assert response.status_code == 503
