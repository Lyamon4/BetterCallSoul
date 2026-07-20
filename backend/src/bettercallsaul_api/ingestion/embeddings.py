import asyncio
import math
import re
from collections.abc import Awaitable, Callable, Sequence

import httpx

from bettercallsaul_api.config import Settings
from bettercallsaul_api.ingestion.models import EmbeddedChunk, LegalChunk


class EmbeddingProviderError(RuntimeError):
    pass


Sleep = Callable[[float], Awaitable[None]]


class GeminiEmbeddingClient:
    def __init__(
        self,
        settings: Settings,
        client: httpx.AsyncClient,
        *,
        batch_size: int = 20,
        retry_delays: tuple[float, ...] = (0.5, 1.5),
        sleep: Sleep = asyncio.sleep,
    ) -> None:
        settings.require_gemini_embeddings()
        if batch_size < 1 or batch_size > 100:
            raise ValueError("batch_size must be between 1 and 100")
        self.settings = settings
        self.client = client
        self.batch_size = batch_size
        self.retry_delays = retry_delays
        self.sleep = sleep

    async def embed_documents(
        self,
        chunks: Sequence[LegalChunk],
    ) -> tuple[EmbeddedChunk, ...]:
        embedded: list[EmbeddedChunk] = []
        for offset in range(0, len(chunks), self.batch_size):
            batch = chunks[offset : offset + self.batch_size]
            vectors = await self._embed_batch(batch)
            embedded.extend(
                EmbeddedChunk(
                    **chunk.model_dump(),
                    embedding=vector,
                    embedding_model=self.settings.gemini_embedding_model,
                    embedding_version=self.settings.gemini_embedding_model,
                )
                for chunk, vector in zip(batch, vectors, strict=True)
            )
        return tuple(embedded)

    async def embed_query(self, query: str) -> tuple[float, ...]:
        normalized_query = " ".join(query.split())
        if not normalized_query:
            raise ValueError("query must not be blank")
        vectors = await self._request_embeddings(
            (f"task: search result | query: {normalized_query}",)
        )
        return vectors[0]

    async def _embed_batch(
        self,
        chunks: Sequence[LegalChunk],
    ) -> tuple[tuple[float, ...], ...]:
        texts = tuple(
            f"title: {chunk.context_heading} | text: {chunk.content}"
            for chunk in chunks
        )
        return await self._request_embeddings(texts)

    async def _request_embeddings(
        self,
        texts: Sequence[str],
    ) -> tuple[tuple[float, ...], ...]:
        model = self.settings.gemini_embedding_model
        payload = {
            "requests": [
                {
                    "model": f"models/{model}",
                    "content": {
                        "parts": [
                            {
                                "text": (
                                    text
                                )
                            }
                        ]
                    },
                    "outputDimensionality": self.settings.gemini_embedding_dimensions,
                }
                for text in texts
            ]
        }
        url = (
            "https://generativelanguage.googleapis.com/v1beta/"
            f"models/{model}:batchEmbedContents"
        )

        for attempt in range(len(self.retry_delays) + 1):
            try:
                response = await self.client.post(
                    url,
                    headers={
                        "Content-Type": "application/json",
                        "x-goog-api-key": self.settings.gemini_api_key,
                    },
                    json=payload,
                    timeout=30.0,
                )
            except (httpx.TimeoutException, httpx.TransportError) as error:
                if await self._retry(attempt):
                    continue
                raise EmbeddingProviderError("Gemini embedding failed.") from error

            if response.status_code in {429, 500, 502, 503, 504}:
                retry_delay = self._provider_retry_delay(response)
                if await self._retry(attempt, retry_delay):
                    continue
                raise EmbeddingProviderError("Gemini embedding failed.")
            if response.status_code != 200:
                raise EmbeddingProviderError("Gemini embedding failed.")

            try:
                decoded = response.json()
                raw_embeddings = decoded["embeddings"]
                if len(raw_embeddings) != len(texts):
                    raise ValueError("embedding count mismatch")
                vectors = tuple(
                    self._validate_vector(item["values"])
                    for item in raw_embeddings
                )
            except (KeyError, TypeError, ValueError) as error:
                raise EmbeddingProviderError("Gemini embedding failed.") from error
            return vectors

        raise EmbeddingProviderError("Gemini embedding failed.")

    def _validate_vector(self, values: object) -> tuple[float, ...]:
        if not isinstance(values, list):
            raise ValueError("embedding must be a list")
        vector = tuple(float(value) for value in values)
        if len(vector) != self.settings.gemini_embedding_dimensions:
            raise ValueError("embedding dimension mismatch")
        if not all(math.isfinite(value) for value in vector):
            raise ValueError("embedding must contain finite values")
        return vector

    async def _retry(
        self,
        attempt: int,
        provider_delay: float | None = None,
    ) -> bool:
        if attempt >= len(self.retry_delays):
            return False
        delay = provider_delay if provider_delay is not None else self.retry_delays[attempt]
        await self.sleep(min(max(delay, 0.0), 60.0))
        return True

    @staticmethod
    def _provider_retry_delay(response: httpx.Response) -> float | None:
        retry_after = response.headers.get("retry-after")
        if retry_after:
            try:
                return float(retry_after)
            except ValueError:
                pass
        try:
            decoded = response.json()
        except (TypeError, ValueError):
            return None
        if not isinstance(decoded, dict):
            return None
        error = decoded.get("error")
        if not isinstance(error, dict):
            return None
        details = error.get("details", [])
        if not isinstance(details, list):
            return None
        for detail in details:
            if not isinstance(detail, dict):
                continue
            raw_delay = detail.get("retryDelay")
            if not isinstance(raw_delay, str):
                continue
            match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)s", raw_delay)
            if match:
                return float(match.group(1))
        return None
