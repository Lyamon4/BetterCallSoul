from datetime import date
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict, ValidationError

from bettercallsaul_api.ingestion.models import CaseCategory


class QueryEmbedder(Protocol):
    async def embed_query(self, query: str) -> tuple[float, ...]: ...


class RetrievalGateway(Protocol):
    async def service_rpc(
        self,
        name: str,
        payload: dict[str, Any],
    ) -> dict[str, Any] | list[Any]: ...


class LegalSearchResult(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    chunk_id: int
    provision_id: int
    source_code: str
    source_title: str
    provision_code: str
    heading: str | None
    content: str
    official_url: str
    revision_code: str
    effective_from: date | None
    effective_to: date | None
    score: float


class RetrievalError(RuntimeError):
    pass


class LegalRetriever:
    def __init__(
        self,
        embedder: QueryEmbedder,
        gateway: RetrievalGateway,
    ) -> None:
        self.embedder = embedder
        self.gateway = gateway

    async def search(
        self,
        *,
        query_text: str,
        category: CaseCategory,
        relevant_on: date,
        match_count: int = 12,
    ) -> tuple[LegalSearchResult, ...]:
        normalized_query = " ".join(query_text.split())
        if not normalized_query:
            raise ValueError("query_text must not be blank")
        if match_count < 1 or match_count > 50:
            raise ValueError("match_count must be between 1 and 50")
        try:
            embedding = await self.embedder.embed_query(normalized_query)
            response = await self.gateway.service_rpc(
                "search_legal_chunks",
                {
                    "query_text": normalized_query,
                    "query_embedding": list(embedding),
                    "case_category": category.value,
                    "relevant_on": relevant_on.isoformat(),
                    "match_count": match_count,
                },
            )
            if not isinstance(response, list):
                raise ValueError("retrieval response must be a list")
            return tuple(LegalSearchResult.model_validate(item) for item in response)
        except (KeyError, TypeError, ValueError, ValidationError) as error:
            raise RetrievalError("Legal retrieval failed.") from error

