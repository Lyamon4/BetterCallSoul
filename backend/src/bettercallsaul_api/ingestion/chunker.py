import hashlib
import re

from bettercallsaul_api.ingestion.models import (
    LegalChunk,
    ParsedProvision,
    ParsedRevision,
    SourceDefinition,
)


TOKEN_PATTERN = re.compile(r"[\w]+|[^\w\s]", re.UNICODE)


def estimate_tokens(text: str) -> int:
    return len(TOKEN_PATTERN.findall(text))


class LegalHierarchyChunker:
    def __init__(self, *, max_tokens: int = 700) -> None:
        if max_tokens < 16:
            raise ValueError("max_tokens must be at least 16")
        self.max_tokens = max_tokens

    def chunk_revision(
        self,
        source: SourceDefinition,
        revision: ParsedRevision,
    ) -> tuple[LegalChunk, ...]:
        chunks: list[LegalChunk] = []
        for provision in revision.provisions:
            chunks.extend(self._chunk_provision(source, revision, provision))
        return tuple(chunks)

    def _chunk_provision(
        self,
        source: SourceDefinition,
        revision: ParsedRevision,
        provision: ParsedProvision,
    ) -> list[LegalChunk]:
        context_heading = " — ".join(
            (source.title, provision.hierarchy_path, provision.heading)
        )
        context_tokens = estimate_tokens(context_heading)
        body_budget = max(1, self.max_tokens - context_tokens)
        paragraph_groups: list[list[str]] = []
        current_group: list[str] = []
        current_tokens = 0

        for raw_paragraph in provision.paragraphs:
            paragraph = " ".join(raw_paragraph.split())
            if not paragraph:
                continue
            paragraph_tokens = estimate_tokens(paragraph)
            if current_group and current_tokens + paragraph_tokens > body_budget:
                paragraph_groups.append(current_group)
                current_group = []
                current_tokens = 0
            current_group.append(paragraph)
            current_tokens += paragraph_tokens

        if current_group:
            paragraph_groups.append(current_group)

        chunks: list[LegalChunk] = []
        for sequence_no, paragraphs in enumerate(paragraph_groups):
            content = "\n".join(paragraphs)
            checksum_input = f"{context_heading}\n{content}".encode("utf-8")
            chunks.append(
                LegalChunk(
                    stable_id=(
                        f"{source.source_code}:{provision.provision_code}:{sequence_no}"
                    ),
                    source_code=source.source_code,
                    provision_code=provision.provision_code,
                    sequence_no=sequence_no,
                    content=content,
                    context_heading=context_heading,
                    token_count=context_tokens + estimate_tokens(content),
                    content_checksum=hashlib.sha256(checksum_input).hexdigest(),
                    metadata={
                        "source_code": source.source_code,
                        "revision_code": revision.revision_code,
                        "provision_code": provision.provision_code,
                        "source_anchor": provision.source_anchor,
                        "categories": [
                            category.value for category in provision.categories
                        ],
                        "sectors": list(provision.sectors),
                    },
                )
            )
        return chunks
