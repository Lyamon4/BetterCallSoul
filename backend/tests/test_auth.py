import pytest
from fastapi.testclient import TestClient

from bettercallsaul_api.config import Settings


def test_settings_reject_missing_supabase_values() -> None:
    settings = Settings(
        environment="test",
        supabase_url="",
        supabase_publishable_key="",
        supabase_secret_key="",
    )

    with pytest.raises(RuntimeError, match="SUPABASE_URL"):
        settings.require_supabase()


def test_me_requires_bearer_token(app_client: TestClient) -> None:
    response = app_client.get("/v1/me")

    assert response.status_code == 401
    assert response.json()["detail"] == "Требуется авторизация."


def test_me_rejects_invalid_bearer_token(app_client: TestClient) -> None:
    response = app_client.get(
        "/v1/me",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Требуется авторизация."


def test_me_returns_verified_user(app_client: TestClient) -> None:
    response = app_client.get(
        "/v1/me",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json() == {"id": "11111111-1111-1111-1111-111111111111"}
