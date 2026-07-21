from datetime import date
from typing import Any

import pytest

from bettercallsaul_api.ingestion.models import CaseCategory
from bettercallsaul_api.retrieval import LegalRetriever, RetrievalError


class Embedder:
    async def embed_query(self, query: str):
        assert query == "оспорить списание"
        return (0.25,) * 768


class Gateway:
    def __init__(self, response: Any) -> None:
        self.response = response
        self.payload: dict[str, Any] | None = None

    async def service_rpc(self, name: str, payload: dict[str, Any]):
        assert name == "search_legal_chunks"
        self.payload = payload
        return self.response


def search_row() -> dict[str, Any]:
    return {
        "chunk_id": 41,
        "provision_id": 11,
        "source_code": "payments_law",
        "source_title": "О платежах и платежных системах",
        "provision_code": "article:25",
        "heading": "Статья 25",
        "content": "Официальный фрагмент.",
        "official_url": "https://adilet.zan.kz/rus/docs/Z1600000011#z25",
        "revision_code": "sha256:1234567890abcdef",
        "effective_from": "2016-07-26",
        "effective_to": None,
        "score": 0.03125,
    }


@pytest.mark.asyncio
async def test_retriever_embeds_and_passes_category_date_filters_inside_rpc() -> None:
    gateway = Gateway([search_row()])

    results = await LegalRetriever(Embedder(), gateway).search(
        query_text="оспорить списание",
        category=CaseCategory.CHARGE,
        relevant_on=date(2026, 7, 20),
        match_count=10,
    )

    assert len(results) == 1
    assert results[0].chunk_id == 41
    assert results[0].source_code == "payments_law"
    assert gateway.payload == {
        "query_text": "оспорить списание",
        "query_embedding": [0.25] * 768,
        "case_category": "charge",
        "relevant_on": "2026-07-20",
        "match_count": 10,
    }


@pytest.mark.asyncio
@pytest.mark.parametrize("response", [{"not": "a list"}, [{"chunk_id": "bad"}]])
async def test_retriever_rejects_malformed_database_response(response: Any) -> None:
    with pytest.raises(RetrievalError, match="Legal retrieval failed"):
        await LegalRetriever(Embedder(), Gateway(response)).search(
            query_text="оспорить списание",
            category=CaseCategory.CHARGE,
            relevant_on=date(2026, 7, 20),
        )


@pytest.mark.asyncio
async def test_retriever_rejects_blank_query_before_provider_call() -> None:
    with pytest.raises(ValueError, match="query_text"):
        await LegalRetriever(Embedder(), Gateway([])).search(
            query_text="   ",
            category=CaseCategory.CHARGE,
            relevant_on=date(2026, 7, 20),
        )

