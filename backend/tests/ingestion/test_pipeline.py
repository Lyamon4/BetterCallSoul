from typing import Any

import pytest

from bettercallsaul_api.ingestion.chunker import LegalHierarchyChunker
from bettercallsaul_api.ingestion.models import (
    EmbeddedChunk,
    FetchedDocument,
    ParsedProvision,
    ParsedRevision,
)
from bettercallsaul_api.ingestion.pipeline import (
    IngestionPipelineError,
    LegalIngestionPipeline,
    preview_source,
)
from bettercallsaul_api.ingestion.source_registry import load_source_registry


CHECKSUM = "d" * 64


def source():
    return next(
        item
        for item in load_source_registry().sources
        if item.source_code == "consumer_protection_law"
    )


def fetched() -> FetchedDocument:
    return FetchedDocument(
        status="fetched",
        requested_url=source().official_url,
        final_url=source().official_url,
        body="<html>fixture</html>",
        content_checksum=CHECKSUM,
        etag='"revision"',
        last_modified=None,
    )


def parsed() -> ParsedRevision:
    provisions = tuple(
        ParsedProvision(
            provision_code=f"article:{index}",
            heading=f"Статья {index}",
            hierarchy_path="Глава 1",
            paragraphs=(f"Официальное правило номер {index}.",),
            source_anchor=f"#z{index}",
            categories=source().categories,
            sectors=source().sectors,
            content_checksum=f"{index:064x}",
        )
        for index in range(1, 4)
    )
    return ParsedRevision(
        source_code=source().source_code,
        revision_code="sha256:dddddddddddddddd",
        effective_from=source().adopted_on,
        content_checksum=CHECKSUM,
        parser_version="test-parser-v1",
        normalized_text="\n".join(
            paragraph
            for provision in provisions
            for paragraph in provision.paragraphs
        ),
        provisions=provisions,
    )


class Fetcher:
    async def fetch(self, definition):
        return fetched()


class Parser:
    def parse(self, definition, document):
        return parsed()


class Embedder:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.calls = 0

    async def embed_documents(self, chunks):
        self.calls += 1
        if self.error:
            raise self.error
        return tuple(
            EmbeddedChunk(
                **chunk.model_dump(),
                embedding=(float(index),) * 768,
                embedding_model="gemini-embedding-2",
                embedding_version="gemini-embedding-2",
            )
            for index, chunk in enumerate(chunks, start=1)
        )


class Gateway:
    def __init__(
        self,
        *,
        start_status: str = "staged",
        fail_on: str | None = None,
    ) -> None:
        self.start_status = start_status
        self.fail_on = fail_on
        self.calls: list[tuple[str, dict[str, Any]]] = []

    async def service_rpc(self, name: str, payload: dict[str, Any]):
        self.calls.append((name, payload))
        if self.fail_on == name:
            raise RuntimeError("external failure")
        if name == "start_legal_ingestion":
            return {
                "status": self.start_status,
                "source_id": 10,
                "revision_id": 20,
                "run_id": 30,
            }
        if name == "finalize_legal_ingestion":
            return {
                "status": "active",
                "revision_id": 20,
                "provision_count": 3,
                "chunk_count": 3,
            }
        if name == "fail_legal_ingestion":
            return {"status": "failed", "revision_id": 20}
        return {"status": "staged", "revision_id": 20}


def make_pipeline(embedder: Embedder, gateway: Gateway) -> LegalIngestionPipeline:
    return LegalIngestionPipeline(
        fetcher=Fetcher(),
        parser=Parser(),
        chunker=LegalHierarchyChunker(max_tokens=100),
        embedder=embedder,
        gateway=gateway,
        embedding_model="gemini-embedding-2",
        provision_batch_size=2,
    )


@pytest.mark.asyncio
async def test_pipeline_stages_batches_and_atomically_activates_revision() -> None:
    gateway = Gateway()
    result = await make_pipeline(Embedder(), gateway).ingest(source(), activate=True)

    assert result.status == "active"
    assert result.provision_count == 3
    assert result.chunk_count == 3
    assert [name for name, _ in gateway.calls] == [
        "start_legal_ingestion",
        "append_legal_ingestion_batch",
        "append_legal_ingestion_batch",
        "finalize_legal_ingestion",
    ]
    start_payload = gateway.calls[0][1]
    assert start_payload["p_source"]["source_code"] == "consumer_protection_law"
    assert start_payload["p_revision"]["content_checksum"] == CHECKSUM
    first_batch = gateway.calls[1][1]["p_provisions"]
    assert len(first_batch) == 2
    assert len(first_batch[0]["chunks"][0]["embedding"]) == 768
    finalize_payload = gateway.calls[-1][1]
    assert finalize_payload == {
        "p_revision_id": 20,
        "p_expected_provision_count": 3,
        "p_expected_chunk_count": 3,
    }


@pytest.mark.asyncio
async def test_pipeline_skips_embedding_when_database_revision_is_unchanged() -> None:
    gateway = Gateway(start_status="unchanged")
    embedder = Embedder()

    result = await make_pipeline(embedder, gateway).ingest(source(), activate=True)

    assert result.status == "unchanged"
    assert embedder.calls == 0
    assert [name for name, _ in gateway.calls] == ["start_legal_ingestion"]


@pytest.mark.asyncio
async def test_pipeline_can_leave_revision_staged_for_manual_review() -> None:
    gateway = Gateway()

    result = await make_pipeline(Embedder(), gateway).ingest(source(), activate=False)

    assert result.status == "staged"
    assert "finalize_legal_ingestion" not in [name for name, _ in gateway.calls]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("embed_error", "gateway_failure"),
    [
        (RuntimeError("embedding unavailable"), None),
        (None, "append_legal_ingestion_batch"),
    ],
)
async def test_pipeline_marks_staged_revision_failed_after_any_downstream_error(
    embed_error: Exception | None,
    gateway_failure: str | None,
) -> None:
    gateway = Gateway(fail_on=gateway_failure)

    with pytest.raises(IngestionPipelineError, match="Legal ingestion failed"):
        await make_pipeline(Embedder(embed_error), gateway).ingest(
            source(), activate=True
        )

    names = [name for name, _ in gateway.calls]
    assert names[-1] == "fail_legal_ingestion"
    assert "finalize_legal_ingestion" not in names
    fail_payload = gateway.calls[-1][1]
    assert fail_payload["p_revision_id"] == 20
    assert fail_payload["p_validation_errors"] == [
        {"code": "ingestion_stage_failed"}
    ]


@pytest.mark.asyncio
async def test_preview_fetches_parses_and_chunks_without_ai_or_database() -> None:
    result = await preview_source(
        source(),
        fetcher=Fetcher(),
        parser=Parser(),
        chunker=LegalHierarchyChunker(max_tokens=100),
    )

    assert result.status == "dry_run"
    assert result.provision_count == 3
    assert result.chunk_count == 3
    assert result.revision_id is None
