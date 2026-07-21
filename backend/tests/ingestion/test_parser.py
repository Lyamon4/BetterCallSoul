import hashlib
from pathlib import Path

import pytest

from bettercallsaul_api.ingestion.models import FetchedDocument
from bettercallsaul_api.ingestion.parser import LegalSourceParser, SourceParseError
from bettercallsaul_api.ingestion.source_registry import load_source_registry


FIXTURES = Path(__file__).parents[1] / "fixtures"


def source(source_code: str):
    return next(
        item
        for item in load_source_registry().sources
        if item.source_code == source_code
    )


def fetched(source_code: str, fixture_name: str) -> FetchedDocument:
    definition = source(source_code)
    return FetchedDocument(
        status="fetched",
        requested_url=definition.official_url,
        final_url=definition.official_url,
        body=(FIXTURES / fixture_name).read_text(encoding="utf-8"),
        content_checksum="a" * 64,
        etag=None,
        last_modified=None,
    )


def test_adilet_parser_extracts_deterministic_articles_and_hierarchy() -> None:
    revision = LegalSourceParser().parse(
        source("consumer_protection_law"),
        fetched("consumer_protection_law", "adilet_consumer_excerpt.html"),
    )

    expected_checksum = hashlib.sha256(
        revision.normalized_text.encode("utf-8")
    ).hexdigest()
    assert revision.content_checksum == expected_checksum
    assert revision.revision_code == f"sha256:{expected_checksum[:16]}"
    assert [item.provision_code for item in revision.provisions] == [
        "article:1",
        "article:2-1",
    ]
    assert revision.provisions[0].heading == "Статья 1. Основные понятия"
    assert revision.provisions[0].hierarchy_path == "Глава 1. ОБЩИЕ ПОЛОЖЕНИЯ"
    assert revision.provisions[0].source_anchor == "#z2"
    assert revision.provisions[1].source_anchor == "#z20"
    assert revision.provisions[0].paragraphs == (
        "В настоящем Законе используются следующие основные понятия:",
        "1) продавец — лицо, реализующее товар;",
    )
    assert "Сноска" not in revision.normalized_text
    assert "Поиск" not in revision.normalized_text


def test_parser_ignores_dynamic_html_outside_normalized_legal_text() -> None:
    definition = source("consumer_protection_law")
    original = fetched("consumer_protection_law", "adilet_consumer_excerpt.html")
    changed_shell = original.model_copy(
        update={
            "body": original.body.replace(
                "<nav>",
                '<script nonce="new-request-id">analytics()</script><nav>',
            ),
            "content_checksum": "b" * 64,
        }
    )

    first = LegalSourceParser().parse(definition, original)
    second = LegalSourceParser().parse(definition, changed_shell)

    assert first.normalized_text == second.normalized_text
    assert first.content_checksum == second.content_checksum
    assert first.revision_code == second.revision_code


def test_adilet_rules_parser_uses_numbered_paragraphs_as_provisions() -> None:
    revision = LegalSourceParser().parse(
        source("payment_card_rules"),
        fetched("payment_card_rules", "adilet_payment_rules_excerpt.html"),
    )

    assert [item.provision_code for item in revision.provisions] == [
        "paragraph:z2",
        "paragraph:z3",
        "paragraph:z7",
    ]
    assert revision.provisions[1].heading == "Пункт 2"
    assert revision.provisions[1].hierarchy_path == "Глава 1. Общие положения"
    assert revision.provisions[1].paragraphs == (
        "2. В Правилах используются понятия, предусмотренные законодательством.",
        "1) эмитент — банк, выпустивший платежную карточку;",
        "2) держатель — физическое лицо, использующее карточку.",
    )
    assert revision.provisions[2].source_anchor == "#z7"


def test_official_guidance_parser_uses_main_content_only() -> None:
    revision = LegalSourceParser().parse(
        source("egov_eotinish_guidance"),
        fetched("egov_eotinish_guidance", "egov_guidance_excerpt.html"),
    )

    assert len(revision.provisions) == 1
    provision = revision.provisions[0]
    assert provision.provision_code == "guidance:main"
    assert provision.heading == "Электронные обращения"
    assert provision.paragraphs == (
        "Как подать обращение через портал eOtinish:",
        "Авторизоваться на портале.",
        "Заполнить форму обращения.",
        "Подписать обращение ЭЦП и отправить.",
    )
    assert "Служба поддержки" not in revision.normalized_text
    assert "analytics" not in revision.normalized_text


@pytest.mark.parametrize(
    ("source_code", "html"),
    [
        ("consumer_protection_law", "<html><article><p>Нет статей</p></article></html>"),
        ("egov_eotinish_guidance", "<html><main><h1>Пусто</h1></main></html>"),
    ],
)
def test_parser_rejects_pages_without_minimum_legal_structure(
    source_code: str, html: str
) -> None:
    definition = source(source_code)
    document = FetchedDocument(
        status="fetched",
        requested_url=definition.official_url,
        final_url=definition.official_url,
        body=html,
        content_checksum="b" * 64,
        etag=None,
        last_modified=None,
    )

    with pytest.raises(SourceParseError, match="Official source could not be parsed"):
        LegalSourceParser().parse(definition, document)
