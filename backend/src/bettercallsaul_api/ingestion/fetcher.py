import asyncio
import hashlib
import ssl
from collections.abc import Awaitable, Callable
from urllib.parse import urlsplit

import httpx
import truststore

from bettercallsaul_api.ingestion.models import (
    OFFICIAL_SOURCE_HOSTS,
    FetchedDocument,
    SourceDefinition,
)


class IngestionFetchError(RuntimeError):
    pass


Sleep = Callable[[float], Awaitable[None]]


def build_system_ssl_context() -> ssl.SSLContext:
    return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)


class OfficialSourceFetcher:
    def __init__(
        self,
        client: httpx.AsyncClient,
        *,
        max_response_bytes: int = 8_000_000,
        retry_delays: tuple[float, ...] = (0.25, 1.0),
        sleep: Sleep = asyncio.sleep,
    ) -> None:
        self.client = client
        self.max_response_bytes = max_response_bytes
        self.retry_delays = retry_delays
        self.sleep = sleep

    async def fetch(
        self,
        source: SourceDefinition,
        *,
        etag: str | None = None,
        last_modified: str | None = None,
    ) -> FetchedDocument:
        headers = {
            "User-Agent": (
                "curl/8.7.1 BetterCallSaul-LegalIngestion/1.0 "
                "(+official-source-refresh)"
            ),
            "Accept": "text/html,application/xhtml+xml",
        }
        if etag:
            headers["If-None-Match"] = etag
        if last_modified:
            headers["If-Modified-Since"] = last_modified

        for attempt in range(len(self.retry_delays) + 1):
            try:
                response = await self.client.get(
                    source.official_url,
                    headers=headers,
                    follow_redirects=True,
                    timeout=20.0,
                )
            except (httpx.TimeoutException, httpx.TransportError) as error:
                if await self._retry(attempt):
                    continue
                raise IngestionFetchError(
                    "Official source could not be fetched."
                ) from error

            if not self._is_official_url(str(response.url)):
                raise IngestionFetchError("Official source could not be fetched.")

            if response.status_code == 304:
                return FetchedDocument(
                    status="unchanged",
                    requested_url=source.official_url,
                    final_url=str(response.url),
                    body=None,
                    content_checksum=None,
                    etag=response.headers.get("etag") or etag,
                    last_modified=response.headers.get("last-modified") or last_modified,
                )

            if response.status_code in {429, 500, 502, 503, 504}:
                if await self._retry(attempt):
                    continue
                raise IngestionFetchError("Official source could not be fetched.")

            if response.status_code != 200:
                raise IngestionFetchError("Official source could not be fetched.")

            content_type = response.headers.get("content-type", "").lower()
            if not content_type.startswith(("text/html", "application/xhtml+xml")):
                raise IngestionFetchError("Official source could not be fetched.")
            if len(response.content) > self.max_response_bytes:
                raise IngestionFetchError("Official source could not be fetched.")

            return FetchedDocument(
                status="fetched",
                requested_url=source.official_url,
                final_url=str(response.url),
                body=response.text,
                content_checksum=hashlib.sha256(response.content).hexdigest(),
                etag=response.headers.get("etag"),
                last_modified=response.headers.get("last-modified"),
            )

        raise IngestionFetchError("Official source could not be fetched.")

    async def _retry(self, attempt: int) -> bool:
        if attempt >= len(self.retry_delays):
            return False
        await self.sleep(self.retry_delays[attempt])
        return True

    @staticmethod
    def _is_official_url(url: str) -> bool:
        parsed = urlsplit(url)
        return (
            parsed.scheme == "https"
            and parsed.hostname in OFFICIAL_SOURCE_HOSTS
            and parsed.username is None
            and parsed.password is None
            and parsed.port is None
        )
