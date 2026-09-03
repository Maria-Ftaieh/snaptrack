"""Smoke tests for the HTTP layer using an in-memory SQLite DB."""
import os
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("API_KEY", "test-key")
os.environ.setdefault("DB_PATH", ":memory:")


@pytest.fixture
def client(tmp_path, monkeypatch) -> Iterator[TestClient]:
    # Point the app at a fresh per-test SQLite file so each test is isolated.
    db_file = tmp_path / "test.db"
    monkeypatch.setenv("DB_PATH", str(db_file))

    # Reload modules so they pick up the new DB_PATH.
    import importlib

    from app import config, database, main, models  # noqa: F401
    importlib.reload(config)
    importlib.reload(database)
    importlib.reload(models)
    # Re-import routers so they bind to the reloaded database module.
    from app.routers import scores as scores_router
    from app.routers import stats as stats_router
    from app.routers import users as users_router
    importlib.reload(users_router)
    importlib.reload(scores_router)
    importlib.reload(stats_router)
    importlib.reload(main)

    with TestClient(main.app) as c:
        yield c


HEADERS = {"X-API-Key": "test-key"}


def test_health_does_not_require_key(client):
    r = client.get("/health")
    assert r.status_code == 200


def test_requires_api_key(client):
    r = client.get("/users")
    assert r.status_code == 401


def test_create_and_list_users(client):
    r = client.post("/users", json={"name": "Ali"}, headers=HEADERS)
    assert r.status_code == 201
    uid = r.json()["id"]

    r = client.get("/users", headers=HEADERS)
    assert r.status_code == 200
    body = r.json()
    assert len(body) == 1
    assert body[0]["id"] == uid
    assert body[0]["latest_score"] is None


def test_log_score_and_stats(client):
    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)
    six_days_ago = (now - timedelta(days=6)).isoformat()
    just_now = now.isoformat()

    uid = client.post("/users", json={"name": "Veli"}, headers=HEADERS).json()["id"]

    r = client.post(f"/users/{uid}/scores",
                    json={"score": 1000, "recorded_at": six_days_ago},
                    headers=HEADERS)
    assert r.status_code == 201

    r = client.post(f"/users/{uid}/scores",
                    json={"score": 1500, "recorded_at": just_now},
                    headers=HEADERS)
    assert r.status_code == 201

    r = client.get(f"/users/{uid}/stats", headers=HEADERS)
    assert r.status_code == 200
    body = r.json()
    assert body["current_score"] == 1500
    # Both logs fall inside the last-7-days window; baseline falls back to first
    # in-period log, so delta = 1500 - 1000 = 500.
    assert body["last_7_days"]["delta"] == 500
    assert len(body["time_series"]) == 2
    assert len(body["hourly_activity"]) == 24
