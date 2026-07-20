import asyncio
import math
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

    async def _embed_batch(
        self,
        chunks: Sequence[LegalChunk],
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
                                    f"title: {chunk.context_heading} | "
                                    f"text: {chunk.content}"
                                )
                            }
                        ]
                    },
                    "outputDimensionality": self.settings.gemini_embedding_dimensions,
                }
                for chunk in chunks
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
                if await self._retry(attempt):
                    continue
                raise EmbeddingProviderError("Gemini embedding failed.")
            if response.status_code != 200:
                raise EmbeddingProviderError("Gemini embedding failed.")

            try:
                decoded = response.json()
                raw_embeddings = decoded["embeddings"]
                if len(raw_embeddings) != len(chunks):
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

    async def _retry(self, attempt: int) -> bool:
        if attempt >= len(self.retry_delays):
            return False
        await self.sleep(self.retry_delays[attempt])
        return True
