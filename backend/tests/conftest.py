from collections.abc import Iterator

import httpx
import pytest
from fastapi.testclient import TestClient

from bettercallsaul_api.config import Settings
from bettercallsaul_api.main import create_app


@pytest.fixture
def settings() -> Settings:
    return Settings(
        environment="test",
        supabase_url="https://example.supabase.co",
        supabase_publishable_key="publishable-key",
        supabase_secret_key="",
    )


@pytest.fixture
def supabase_transport() -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.headers.get("authorization") == "Bearer valid-token":
            return httpx.Response(
                200,
                json={
                    "id": "11111111-1111-1111-1111-111111111111",
                    "aud": "authenticated",
                    "role": "authenticated",
                    "email": "user@example.com",
                    "email_confirmed_at": "2026-07-20T00:00:00Z",
                    "phone": "",
                    "confirmed_at": "2026-07-20T00:00:00Z",
                    "last_sign_in_at": "2026-07-20T00:00:00Z",
                    "app_metadata": {"provider": "email", "providers": ["email"]},
                    "user_metadata": {},
                    "identities": [],
                    "created_at": "2026-07-20T00:00:00Z",
                    "updated_at": "2026-07-20T00:00:00Z",
                    "is_anonymous": False,
                },
            )
        return httpx.Response(401, json={"message": "Invalid JWT"})

    return httpx.MockTransport(handler)


@pytest.fixture
def app_client(
    settings: Settings,
    supabase_transport: httpx.MockTransport,
) -> Iterator[TestClient]:
    with TestClient(create_app(settings=settings, transport=supabase_transport)) as client:
        yield client
