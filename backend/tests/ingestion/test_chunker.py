from bettercallsaul_api.ingestion.chunker import LegalHierarchyChunker
from bettercallsaul_api.ingestion.models import ParsedProvision, ParsedRevision
from bettercallsaul_api.ingestion.source_registry import load_source_registry


CHECKSUM = "c" * 64


def consumer_source():
    return next(
        source
        for source in load_source_registry().sources
        if source.source_code == "consumer_protection_law"
    )


def revision(*provisions: ParsedProvision) -> ParsedRevision:
    return ParsedRevision(
        source_code="consumer_protection_law",
        revision_code="sha256:cccccccccccccccc",
        effective_from=None,
        content_checksum=CHECKSUM,
        parser_version="test-v1",
        normalized_text="\n".join(
            paragraph
            for provision in provisions
            for paragraph in provision.paragraphs
        ),
        provisions=provisions,
    )


def provision(code: str, *paragraphs: str) -> ParsedProvision:
    return ParsedProvision(
        provision_code=code,
        heading=f"Статья {code.removeprefix('article:')}",
        hierarchy_path="Глава 1. Общие положения",
        paragraphs=paragraphs,
        source_anchor="#z1",
        categories=consumer_source().categories,
        sectors=consumer_source().sectors,
        content_checksum=CHECKSUM,
    )


def test_short_provision_stays_in_one_contextual_chunk() -> None:
    parsed = revision(
        provision(
            "article:1",
            "Потребитель вправе получить достоверную информацию.",
            "Продавец обязан предоставить такую информацию.",
        )
    )

    chunks = LegalHierarchyChunker(max_tokens=100).chunk_revision(
        consumer_source(), parsed
    )

    assert len(chunks) == 1
    assert chunks[0].provision_code == "article:1"
    assert chunks[0].sequence_no == 0
    assert chunks[0].context_heading == (
        "О защите прав потребителей — Глава 1. Общие положения — Статья 1"
    )
    assert chunks[0].content == (
        "Потребитель вправе получить достоверную информацию.\n"
        "Продавец обязан предоставить такую информацию."
    )
    assert chunks[0].token_count > 0


def test_long_provision_splits_only_between_paragraphs() -> None:
    paragraphs = tuple(
        f"Пункт {index} содержит восемь отдельных слов для проверки границы чанка."
        for index in range(1, 7)
    )
    parsed = revision(provision("article:2", *paragraphs))

    chunks = LegalHierarchyChunker(max_tokens=28).chunk_revision(
        consumer_source(), parsed
    )

    assert len(chunks) > 1
    assert [chunk.sequence_no for chunk in chunks] == list(range(len(chunks)))
    reconstructed = tuple(
        paragraph
        for chunk in chunks
        for paragraph in chunk.content.split("\n")
    )
    assert reconstructed == paragraphs
    assert all(chunk.provision_code == "article:2" for chunk in chunks)


def test_chunks_never_cross_provision_boundaries_and_keep_metadata() -> None:
    parsed = revision(
        provision("article:1", "Первое правило."),
        provision("article:2", "Второе правило."),
    )

    chunks = LegalHierarchyChunker(max_tokens=100).chunk_revision(
        consumer_source(), parsed
    )

    assert [chunk.provision_code for chunk in chunks] == ["article:1", "article:2"]
    assert chunks[0].metadata["categories"] == [
        category.value for category in consumer_source().categories
    ]
    assert chunks[0].metadata["sectors"] == list(consumer_source().sectors)
    assert chunks[0].metadata["source_code"] == "consumer_protection_law"


def test_chunk_ids_and_checksums_are_deterministic() -> None:
    parsed = revision(provision("article:1", "Одно и то же содержание."))
    chunker = LegalHierarchyChunker(max_tokens=100)

    first = chunker.chunk_revision(consumer_source(), parsed)
    second = chunker.chunk_revision(consumer_source(), parsed)

    assert first == second
    assert first[0].stable_id == "consumer_protection_law:article:1:0"
    assert len(first[0].content_checksum) == 64


def test_empty_paragraph_text_never_creates_an_empty_chunk() -> None:
    parsed = revision(provision("article:1", "   ", "Рабочее правило."))

    chunks = LegalHierarchyChunker(max_tokens=100).chunk_revision(
        consumer_source(), parsed
    )

    assert len(chunks) == 1
    assert chunks[0].content == "Рабочее правило."
