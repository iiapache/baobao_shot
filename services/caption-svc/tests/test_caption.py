import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.caption import CaptionService
from app.store.memory import MemoryStore

PAYLOAD = {
    "babyId": "bb_01HZ",
    "ageDays": 312,
    "play": "ghibli_kid",
    "location": "杭州",
}


def _auth_headers(user: str = "dev") -> dict[str, str]:
    return {"Authorization": f"Bearer {user}"}


def test_generate_requires_auth(client: TestClient):
    response = client.post("/v1/caption/generate", json=PAYLOAD)
    assert response.status_code == 401
    body = response.json()
    assert body["code"] == "AUTH_UNAUTHORIZED"


def test_generate_returns_three_candidates(client: TestClient):
    response = client.post("/v1/caption/generate", json=PAYLOAD, headers=_auth_headers())
    assert response.status_code == 200
    body = response.json()
    assert body["code"] == "OK"
    assert "requestId" in body
    data = body["data"]
    assert len(data["candidates"]) == 3
    assert all("text" in item and "hashtags" in item for item in data["candidates"])
    assert data["remainingToday"] == 49


def test_generate_uses_gateway_user_header(client: TestClient):
    response = client.post(
        "/v1/caption/generate",
        json=PAYLOAD,
        headers={"X-User-Id": "usr_gateway"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["remainingToday"] == 49


def test_cache_hit_does_not_consume_quota(memory_store: MemoryStore):
    app.state.store = memory_store
    app.state.caption_service = CaptionService(memory_store, daily_limit=50)
    client = TestClient(app)

    first = client.post("/v1/caption/generate", json=PAYLOAD, headers=_auth_headers())
    second = client.post("/v1/caption/generate", json=PAYLOAD, headers=_auth_headers())

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["data"]["remainingToday"] == 49
    assert second.json()["data"]["remainingToday"] == 49
    assert first.json()["data"]["candidates"] == second.json()["data"]["candidates"]


def test_daily_limit_returns_caption_daily_limit(memory_store: MemoryStore):
    app.state.store = memory_store
    app.state.caption_service = CaptionService(memory_store, daily_limit=2)
    client = TestClient(app)

    for idx in range(2):
        response = client.post(
            "/v1/caption/generate",
            json={**PAYLOAD, "babyId": f"bb_limit_{idx}"},
            headers=_auth_headers("dev:usr_limit"),
        )
        assert response.status_code == 200

    blocked = client.post(
        "/v1/caption/generate",
        json={**PAYLOAD, "babyId": "bb_limit_blocked"},
        headers=_auth_headers("dev:usr_limit"),
    )
    assert blocked.status_code == 429
    body = blocked.json()
    assert body["code"] == "CAPTION_DAILY_LIMIT"
    assert "requestId" in body


@pytest.mark.parametrize("token,expected_remaining", [("dev", 49), ("dev:usr_a", 49)])
def test_dev_token_variants(client: TestClient, token: str, expected_remaining: int):
    response = client.post(
        "/v1/caption/generate",
        json={**PAYLOAD, "babyId": f"bb_{token}"},
        headers=_auth_headers(token),
    )
    assert response.status_code == 200
    assert response.json()["data"]["remainingToday"] == expected_remaining
