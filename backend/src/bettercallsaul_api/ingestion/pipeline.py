from collections.abc import Sequence
from typing import Any, Protocol

from bettercallsaul_api.ingestion.chunker import LegalHierarchyChunker
from bettercallsaul_api.ingestion.embeddings import EmbeddingQuotaExceeded
from bettercallsaul_api.ingestion.models import (
    EmbeddedChunk,
    FetchedDocument,
    IngestionResult,
    LegalChunk,
    ParsedProvision,
    ParsedRevision,
    SourceDefinition,
)


class Fetcher(Protocol):
    async def fetch(self, source: SourceDefinition) -> FetchedDocument: ...


class Parser(Protocol):
    def parse(
        self,
        source: SourceDefinition,
        document: FetchedDocument,
    ) -> ParsedRevision: ...


class Embedder(Protocol):
    async def embed_documents(
        self,
        chunks: Sequence[LegalChunk],
    ) -> tuple[EmbeddedChunk, ...]: ...


class ServiceGateway(Protocol):
    async def service_rpc(
        self,
        name: str,
        payload: dict[str, Any],
    ) -> dict[str, Any] | list[Any]: ...


class IngestionPipelineError(RuntimeError):
    pass


class IngestionPausedError(IngestionPipelineError):
    pass


async def preview_source(
    source: SourceDefinition,
    *,
    fetcher: Fetcher,
    parser: Parser,
    chunker: LegalHierarchyChunker,
) -> IngestionResult:
    document = await fetcher.fetch(source)
    if document.status == "unchanged":
        return IngestionResult(
            status="unchanged",
            source_code=source.source_code,
            provision_count=0,
            chunk_count=0,
        )
    revision = parser.parse(source, document)
    chunks = chunker.chunk_revision(source, revision)
    return IngestionResult(
        status="dry_run",
        source_code=source.source_code,
        provision_count=len(revision.provisions),
        chunk_count=len(chunks),
    )


class LegalIngestionPipeline:
    def __init__(
        self,
        *,
        fetcher: Fetcher,
        parser: Parser,
        chunker: LegalHierarchyChunker,
        embedder: Embedder,
        gateway: ServiceGateway,
        embedding_model: str,
        provision_batch_size: int = 10,
    ) -> None:
        if provision_batch_size < 1 or provision_batch_size > 50:
            raise ValueError("provision_batch_size must be between 1 and 50")
        self.fetcher = fetcher
        self.parser = parser
        self.chunker = chunker
        self.embedder = embedder
        self.gateway = gateway
        self.embedding_model = embedding_model
        self.provision_batch_size = provision_batch_size

    async def ingest(
        self,
        source: SourceDefinition,
        *,
        activate: bool,
    ) -> IngestionResult:
        revision_id: int | None = None
        try:
            document = await self.fetcher.fetch(source)
            if document.status == "unchanged":
                return IngestionResult(
                    status="unchanged",
                    source_code=source.source_code,
                    provision_count=0,
                    chunk_count=0,
                )
            revision = self.parser.parse(source, document)
            start_response = await self.gateway.service_rpc(
                "start_legal_ingestion",
                {
                    "p_source": self._source_payload(source),
                    "p_revision": self._revision_payload(revision),
                },
            )
            if not isinstance(start_response, dict):
                raise ValueError("invalid start response")
            if start_response.get("status") == "unchanged":
                return IngestionResult(
                    status="unchanged",
                    source_code=source.source_code,
                    revision_id=self._optional_int(start_response.get("revision_id")),
                    provision_count=int(start_response.get("provision_count", 0)),
                    chunk_count=int(start_response.get("chunk_count", 0)),
                )

            revision_id = int(start_response["revision_id"])
            chunks = self.chunker.chunk_revision(source, revision)
            if not chunks:
                raise ValueError("revision produced no chunks")
            completed_codes = self._completed_provision_codes(
                start_response,
                revision.provisions,
            )
            chunks_by_provision: dict[str, list[LegalChunk]] = {}
            for chunk in chunks:
                chunks_by_provision.setdefault(chunk.provision_code, []).append(chunk)
            remaining_provisions = tuple(
                provision
                for provision in revision.provisions
                if provision.provision_code not in completed_codes
            )
            for offset in range(
                0,
                len(remaining_provisions),
                self.provision_batch_size,
            ):
                provision_batch = remaining_provisions[
                    offset : offset + self.provision_batch_size
                ]
                chunk_batch = tuple(
                    chunk
                    for provision in provision_batch
                    for chunk in sorted(
                        chunks_by_provision.get(provision.provision_code, []),
                        key=lambda item: item.sequence_no,
                    )
                )
                if not chunk_batch:
                    raise ValueError("provision batch produced no chunks")
                embedded_chunks = await self.embedder.embed_documents(chunk_batch)
                provision_payloads = self._provision_payloads(
                    provision_batch,
                    embedded_chunks,
                )
                await self.gateway.service_rpc(
                    "append_legal_ingestion_batch",
                    {
                        "p_revision_id": revision_id,
                        "p_provisions": provision_payloads,
                    },
                )

            if not activate:
                return IngestionResult(
                    status="staged",
                    source_code=source.source_code,
                    revision_id=revision_id,
                    provision_count=len(revision.provisions),
                    chunk_count=len(chunks),
                )

            finalize_response = await self.gateway.service_rpc(
                "finalize_legal_ingestion",
                {
                    "p_revision_id": revision_id,
                    "p_expected_provision_count": len(revision.provisions),
                    "p_expected_chunk_count": len(chunks),
                },
            )
            if not isinstance(finalize_response, dict) or (
                finalize_response.get("status") != "active"
            ):
                raise ValueError("invalid finalize response")
            return IngestionResult(
                status="active",
                source_code=source.source_code,
                revision_id=revision_id,
                provision_count=len(revision.provisions),
                chunk_count=len(chunks),
            )
        except EmbeddingQuotaExceeded as error:
            if revision_id is not None:
                try:
                    await self.gateway.service_rpc(
                        "pause_legal_ingestion",
                        {
                            "p_revision_id": revision_id,
                            "p_validation_errors": [
                                {"code": "embedding_quota_exhausted"}
                            ],
                        },
                    )
                except Exception:
                    pass
            raise IngestionPausedError("Legal ingestion paused.") from error
        except Exception as error:
            if revision_id is not None:
                try:
                    await self.gateway.service_rpc(
                        "fail_legal_ingestion",
                        {
                            "p_revision_id": revision_id,
                            "p_validation_errors": [
                                {"code": "ingestion_stage_failed"}
                            ],
                        },
                    )
                except Exception:
                    pass
            raise IngestionPipelineError("Legal ingestion failed.") from error

    def _source_payload(self, source: SourceDefinition) -> dict[str, Any]:
        return {
            "source_code": source.source_code,
            "title": source.title,
            "authority": source.authority,
            "official_url": source.official_url,
            "jurisdiction": source.jurisdiction,
            "language": source.language,
            "document_type": source.document_type,
            "adopted_on": (
                source.adopted_on.isoformat() if source.adopted_on else None
            ),
        }

    def _revision_payload(self, revision: ParsedRevision) -> dict[str, Any]:
        return {
            "revision_code": revision.revision_code,
            "effective_from": (
                revision.effective_from.isoformat() if revision.effective_from else None
            ),
            "effective_to": (
                revision.effective_to.isoformat() if revision.effective_to else None
            ),
            "content_checksum": revision.content_checksum,
            "parser_version": revision.parser_version,
            "normalized_text": revision.normalized_text,
            "embedding_model": self.embedding_model,
        }

    def _provision_payloads(
        self,
        provisions: Sequence[ParsedProvision],
        chunks: Sequence[EmbeddedChunk],
    ) -> list[dict[str, Any]]:
        chunks_by_provision: dict[str, list[EmbeddedChunk]] = {}
        for chunk in chunks:
            chunks_by_provision.setdefault(chunk.provision_code, []).append(chunk)

        payloads: list[dict[str, Any]] = []
        for provision in provisions:
            provision_chunks = sorted(
                chunks_by_provision.get(provision.provision_code, []),
                key=lambda chunk: chunk.sequence_no,
            )
            if not provision_chunks:
                raise ValueError("provision produced no embedded chunks")
            payloads.append(
                {
                    "provision_code": provision.provision_code,
                    "heading": provision.heading,
                    "hierarchy_path": provision.hierarchy_path,
                    "normalized_text": "\n".join(provision.paragraphs),
                    "source_anchor": provision.source_anchor,
                    "categories": [
                        category.value for category in provision.categories
                    ],
                    "sectors": list(provision.sectors),
                    "content_checksum": provision.content_checksum,
                    "chunks": [
                        {
                            "sequence_no": chunk.sequence_no,
                            "content": chunk.content,
                            "context_heading": chunk.context_heading,
                            "token_count": chunk.token_count,
                            "embedding": list(chunk.embedding),
                            "embedding_model": chunk.embedding_model,
                            "embedding_version": chunk.embedding_version,
                            "metadata": chunk.metadata,
                        }
                        for chunk in provision_chunks
                    ],
                }
            )
        return payloads

    @staticmethod
    def _completed_provision_codes(
        start_response: dict[str, Any],
        provisions: Sequence[ParsedProvision],
    ) -> set[str]:
        raw_codes = start_response.get("completed_provision_codes", [])
        if not isinstance(raw_codes, list) or not all(
            isinstance(code, str) for code in raw_codes
        ):
            raise ValueError("invalid completed provision codes")
        completed_codes = set(raw_codes)
        available_codes = {provision.provision_code for provision in provisions}
        if not completed_codes.issubset(available_codes):
            raise ValueError("completed provision does not exist in revision")
        return completed_codes

    @staticmethod
    def _optional_int(value: object) -> int | None:
        return int(value) if value is not None else None
