from fastapi.testclient import TestClient

from bettercallsaul_api.main import create_app


def test_health_returns_stable_contract() -> None:
    response = TestClient(create_app()).get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "bettercallsaul-api",
    }
