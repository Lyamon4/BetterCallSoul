import httpx
import pytest

from bettercallsaul_api.config import Settings
from bettercallsaul_api.supabase_gateway import (
    SupabaseGateway,
    SupabaseGatewayError,
)


def make_gateway(
    handler: httpx.MockTransport,
    *,
    secret_key: str = "secret-key",
) -> tuple[SupabaseGateway, httpx.AsyncClient]:
    settings = Settings(
        environment="test",
        supabase_url="https://example.supabase.co",
        supabase_publishable_key="publishable-key",
        supabase_secret_key=secret_key,
    )
    client = httpx.AsyncClient(transport=handler)
    return SupabaseGateway(settings=settings, client=client), client


@pytest.mark.asyncio
async def test_user_request_forwards_user_jwt_not_secret() -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(200, json=[])

    gateway, client = make_gateway(httpx.MockTransport(handler))
    try:
        result = await gateway.user_request(
            "GET",
            "/rest/v1/cases",
            "user-jwt",
        )
    finally:
        await client.aclose()

    request = captured[0]
    assert result == []
    assert request.url == "https://example.supabase.co/rest/v1/cases"
    assert request.headers["authorization"] == "Bearer user-jwt"
    assert request.headers["apikey"] == "publishable-key"
    assert "secret-key" not in str(request.headers)


@pytest.mark.asyncio
async def test_service_rpc_uses_secret_only_for_allowed_rpc() -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(200, json=[{"chunk_id": 1}])

    gateway, client = make_gateway(httpx.MockTransport(handler))
    try:
        result = await gateway.service_rpc(
            "search_legal_chunks",
            {"query_text": "списание"},
        )
    finally:
        await client.aclose()

    request = captured[0]
    assert result == [{"chunk_id": 1}]
    assert request.url.path.endswith("/rest/v1/rpc/search_legal_chunks")
    assert request.headers["authorization"] == "Bearer secret-key"
    assert request.headers["apikey"] == "secret-key"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "rpc_name",
    [
        "start_legal_ingestion",
        "append_legal_ingestion_batch",
        "finalize_legal_ingestion",
        "fail_legal_ingestion",
    ],
)
async def test_ingestion_service_rpcs_are_explicitly_allowed(rpc_name: str) -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(200, json={"status": "ok"})

    gateway, client = make_gateway(httpx.MockTransport(handler))
    try:
        result = await gateway.service_rpc(rpc_name, {"safe": "payload"})
    finally:
        await client.aclose()

    assert result == {"status": "ok"}
    assert captured[0].url.path.endswith(f"/rest/v1/rpc/{rpc_name}")


@pytest.mark.asyncio
async def test_service_rpc_rejects_any_other_function_name() -> None:
    gateway, client = make_gateway(
        httpx.MockTransport(lambda request: httpx.Response(200, json=[]))
    )
    try:
        with pytest.raises(ValueError, match="not allowed"):
            await gateway.service_rpc("delete_everything", {})
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_service_rpc_requires_backend_secret() -> None:
    gateway, client = make_gateway(
        httpx.MockTransport(lambda request: httpx.Response(200, json=[])),
        secret_key="",
    )
    try:
        with pytest.raises(RuntimeError, match="SUPABASE_SECRET_KEY"):
            await gateway.service_rpc("search_legal_chunks", {})
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_provider_error_does_not_expose_response_body() -> None:
    gateway, client = make_gateway(
        httpx.MockTransport(
            lambda request: httpx.Response(
                500,
                json={"message": "secret provider diagnostic"},
            )
        )
    )
    try:
        with pytest.raises(SupabaseGatewayError) as error:
            await gateway.user_request("GET", "/rest/v1/cases", "user-jwt")
    finally:
        await client.aclose()

    assert str(error.value) == "Supabase request failed."
    assert "secret provider diagnostic" not in str(error.value)
