import ssl

import httpx
import pytest

from bettercallsaul_api.ingestion.fetcher import (
    IngestionFetchError,
    OfficialSourceFetcher,
    build_system_ssl_context,
)
from bettercallsaul_api.ingestion.source_registry import load_source_registry


def consumer_source():
    return next(
        source
        for source in load_source_registry().sources
        if source.source_code == "consumer_protection_law"
    )


@pytest.mark.asyncio
async def test_fetcher_returns_html_metadata_and_stable_checksum() -> None:
    body = "<html><article>Официальный текст закона</article></html>"

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["user-agent"].startswith("curl/")
        assert "BetterCallSaul-LegalIngestion/" in request.headers["user-agent"]
        return httpx.Response(
            200,
            text=body,
            headers={
                "content-type": "text/html; charset=utf-8",
                "etag": '"revision-1"',
                "last-modified": "Mon, 20 Jul 2026 10:00:00 GMT",
            },
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        result = await OfficialSourceFetcher(client).fetch(consumer_source())

    assert result.status == "fetched"
    assert result.body == body
    assert result.content_checksum == "54bc8f7e24debe131c7db175dea40d6dbbec59dfdc83e720265f2677f06dfd07"
    assert result.etag == '"revision-1"'
    assert result.last_modified == "Mon, 20 Jul 2026 10:00:00 GMT"
    assert result.final_url == consumer_source().official_url


def test_system_ssl_context_keeps_certificate_verification_enabled() -> None:
    context = build_system_ssl_context()

    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname is True


@pytest.mark.asyncio
async def test_fetcher_sends_conditional_headers_and_handles_unchanged_source() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["if-none-match"] == '"revision-1"'
        assert request.headers["if-modified-since"] == "Sun, 19 Jul 2026 10:00:00 GMT"
        return httpx.Response(304, request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        result = await OfficialSourceFetcher(client).fetch(
            consumer_source(),
            etag='"revision-1"',
            last_modified="Sun, 19 Jul 2026 10:00:00 GMT",
        )

    assert result.status == "unchanged"
    assert result.body is None
    assert result.content_checksum is None


@pytest.mark.asyncio
async def test_fetcher_retries_transient_responses() -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            return httpx.Response(503, request=request)
        return httpx.Response(
            200,
            text="<html><article>ready</article></html>",
            headers={"content-type": "text/html"},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        await OfficialSourceFetcher(client, retry_delays=(0, 0)).fetch(consumer_source())

    assert attempts == 3


@pytest.mark.asyncio
async def test_fetcher_rejects_redirect_to_unofficial_host() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "adilet.zan.kz":
            return httpx.Response(
                302,
                headers={"location": "https://evil.example/law"},
                request=request,
            )
        return httpx.Response(
            200,
            text="<html>fake</html>",
            headers={"content-type": "text/html"},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(IngestionFetchError, match="Official source could not be fetched"):
            await OfficialSourceFetcher(client).fetch(consumer_source())


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("headers", "body"),
    [
        ({"content-type": "application/pdf"}, "not html"),
        ({"content-type": "text/html"}, "x" * 101),
    ],
)
async def test_fetcher_rejects_wrong_content_type_or_oversized_body(
    headers: dict[str, str], body: str
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text=body, headers=headers, request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(IngestionFetchError, match="Official source could not be fetched"):
            await OfficialSourceFetcher(client, max_response_bytes=100).fetch(
                consumer_source()
            )


@pytest.mark.asyncio
async def test_fetcher_does_not_leak_provider_response_in_error() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403, text="secret-debug-value", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(IngestionFetchError) as caught:
            await OfficialSourceFetcher(client).fetch(consumer_source())

    assert "secret-debug-value" not in str(caught.value)
