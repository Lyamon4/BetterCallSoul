import json

import httpx
import pytest

from bettercallsaul_api.config import Settings
from bettercallsaul_api.ingestion.embeddings import (
    EmbeddingQuotaExceeded,
    EmbeddingProviderError,
    GeminiEmbeddingClient,
)
from bettercallsaul_api.ingestion.models import LegalChunk


def legal_chunk(sequence_no: int, content: str) -> LegalChunk:
    return LegalChunk(
        stable_id=f"consumer_protection_law:article:1:{sequence_no}",
        source_code="consumer_protection_law",
        provision_code="article:1",
        sequence_no=sequence_no,
        content=content,
        context_heading="О защите прав потребителей — Статья 1",
        token_count=12,
        content_checksum=f"{sequence_no + 1:064x}",
        metadata={"categories": ["product"]},
    )


def settings(api_key: str = "gemini-secret") -> Settings:
    return Settings(
        environment="test",
        gemini_api_key=api_key,
        gemini_embedding_model="gemini-embedding-2",
        gemini_embedding_dimensions=768,
    )


@pytest.mark.asyncio
async def test_batch_embedding_uses_document_prefix_and_768_dimensions() -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(
            200,
            json={
                "embeddings": [
                    {"values": [0.001] * 768},
                    {"values": [0.002] * 768},
                ]
            },
            request=request,
        )

    chunks = (
        legal_chunk(0, "Первый официальный фрагмент."),
        legal_chunk(1, "Второй официальный фрагмент."),
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        embedded = await GeminiEmbeddingClient(settings(), client).embed_documents(
            chunks
        )

    request = captured[0]
    payload = json.loads(request.content)
    assert request.url == (
        "https://generativelanguage.googleapis.com/v1beta/"
        "models/gemini-embedding-2:batchEmbedContents"
    )
    assert request.headers["x-goog-api-key"] == "gemini-secret"
    assert "gemini-secret" not in str(request.url)
    assert payload["requests"][0] == {
        "model": "models/gemini-embedding-2",
        "content": {
            "parts": [
                {
                    "text": (
                        "title: О защите прав потребителей — Статья 1 | "
                        "text: Первый официальный фрагмент."
                    )
                }
            ]
        },
        "outputDimensionality": 768,
    }
    assert len(embedded) == 2
    assert len(embedded[0].embedding) == 768
    assert embedded[0].embedding_model == "gemini-embedding-2"
    assert embedded[0].stable_id == chunks[0].stable_id
    assert embedded[1].embedding[0] == 0.002


@pytest.mark.asyncio
async def test_embedding_client_preserves_order_across_bounded_batches() -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        values = []
        for item in payload["requests"]:
            marker = float(item["content"]["parts"][0]["text"].split("Фрагмент ")[1][0])
            values.append({"values": [marker] * 768})
        return httpx.Response(200, json={"embeddings": values}, request=request)

    chunks = tuple(legal_chunk(index, f"Фрагмент {index}.") for index in range(5))
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        embedded = await GeminiEmbeddingClient(
            settings(), client, batch_size=2
        ).embed_documents(chunks)

    assert calls == 3
    assert [item.embedding[0] for item in embedded] == [0.0, 1.0, 2.0, 3.0, 4.0]


@pytest.mark.asyncio
@pytest.mark.parametrize("values", [[0.1] * 767, [float("nan")] * 768])
async def test_embedding_client_rejects_wrong_or_non_finite_vectors(
    values: list[float],
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            content=json.dumps({"embeddings": [{"values": values}]}),
            headers={"content-type": "application/json"},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(EmbeddingProviderError, match="Gemini embedding failed"):
            await GeminiEmbeddingClient(settings(), client).embed_documents(
                (legal_chunk(0, "Текст."),)
            )


@pytest.mark.asyncio
async def test_embedding_client_retries_transient_failure_without_leaking_body() -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            return httpx.Response(
                503,
                json={"error": "secret-provider-diagnostic"},
                request=request,
            )
        return httpx.Response(
            200,
            json={"embeddings": [{"values": [0.1] * 768}]},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        embedded = await GeminiEmbeddingClient(
            settings(), client, retry_delays=(0,)
        ).embed_documents((legal_chunk(0, "Текст."),))

    assert attempts == 2
    assert len(embedded[0].embedding) == 768


@pytest.mark.asyncio
async def test_embedding_client_honors_provider_retry_delay_for_quota_window() -> None:
    attempts = 0
    sleeps: list[float] = []

    async def record_sleep(delay: float) -> None:
        sleeps.append(delay)

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            return httpx.Response(
                429,
                json={
                    "error": {
                        "status": "RESOURCE_EXHAUSTED",
                        "details": [
                            {
                                "@type": "type.googleapis.com/google.rpc.RetryInfo",
                                "retryDelay": "17.25s",
                            }
                        ],
                    }
                },
                request=request,
            )
        return httpx.Response(
            200,
            json={"embeddings": [{"values": [0.1] * 768}]},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        embedded = await GeminiEmbeddingClient(
            settings(),
            client,
            retry_delays=(0,),
            sleep=record_sleep,
        ).embed_documents((legal_chunk(0, "Текст."),))

    assert attempts == 2
    assert sleeps == [17.25]
    assert len(embedded[0].embedding) == 768


@pytest.mark.asyncio
async def test_embedding_client_reports_exhausted_quota_separately() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            429,
            json={
                "error": {
                    "status": "RESOURCE_EXHAUSTED",
                    "details": [
                        {
                            "@type": "type.googleapis.com/google.rpc.RetryInfo",
                            "retryDelay": "23s",
                        }
                    ],
                }
            },
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(EmbeddingQuotaExceeded) as caught:
            await GeminiEmbeddingClient(
                settings(),
                client,
                retry_delays=(),
            ).embed_documents((legal_chunk(0, "Текст."),))

    assert caught.value.retry_after_seconds == 23
    assert str(caught.value) == "Gemini embedding quota is exhausted."


@pytest.mark.asyncio
async def test_embedding_provider_error_is_sanitized() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            403,
            json={"error": "secret-provider-diagnostic"},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(EmbeddingProviderError) as caught:
            await GeminiEmbeddingClient(settings(), client).embed_documents(
                (legal_chunk(0, "Текст."),)
            )

    assert str(caught.value) == "Gemini embedding failed."
    assert "secret-provider-diagnostic" not in str(caught.value)


def test_embedding_client_requires_backend_api_key_and_fixed_dimension() -> None:
    with pytest.raises(RuntimeError, match="GEMINI_API_KEY"):
        GeminiEmbeddingClient(settings(api_key=""), httpx.AsyncClient())

    wrong_dimensions = settings().model_copy(
        update={"gemini_embedding_dimensions": 1536}
    )
    with pytest.raises(RuntimeError, match="768"):
        GeminiEmbeddingClient(wrong_dimensions, httpx.AsyncClient())


@pytest.mark.asyncio
async def test_query_embedding_uses_asymmetric_search_prefix() -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(
            200,
            json={"embeddings": [{"values": [0.5] * 768}]},
            request=request,
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        vector = await GeminiEmbeddingClient(settings(), client).embed_query(
            "оспорить списание с карты"
        )

    payload = json.loads(captured[0].content)
    assert payload["requests"][0]["content"]["parts"][0]["text"] == (
        "task: search result | query: оспорить списание с карты"
    )
    assert len(vector) == 768
