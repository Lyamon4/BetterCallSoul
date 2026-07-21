from copy import deepcopy

import pytest
from pydantic import ValidationError

from bettercallsaul_api.ingestion.models import CaseCategory, SourceRegistry
from bettercallsaul_api.ingestion.source_registry import load_source_registry


EXPECTED_SOURCE_CODES = {
    "consumer_protection_law",
    "civil_code_special",
    "payments_law",
    "payment_card_rules",
    "administrative_offences_code",
    "administrative_procedure_code",
    "egov_eotinish_guidance",
    "consumer_committee_guidance",
}


def test_bundled_registry_contains_only_the_eight_curated_sources() -> None:
    registry = load_source_registry()

    assert {source.source_code for source in registry.sources} == EXPECTED_SOURCE_CODES
    assert len(registry.sources) == 8
    assert all(source.official_url.startswith("https://") for source in registry.sources)
    assert all(source.is_allowlisted for source in registry.sources)


def test_bundled_registry_covers_every_supported_case_category() -> None:
    registry = load_source_registry()

    covered = {category for source in registry.sources for category in source.categories}

    assert covered == set(CaseCategory)


def test_registry_rejects_duplicate_source_codes() -> None:
    registry = load_source_registry()
    payload = registry.model_dump(mode="json")
    payload["sources"].append(deepcopy(payload["sources"][0]))

    with pytest.raises(ValidationError, match="source_code values must be unique"):
        SourceRegistry.model_validate(payload)


@pytest.mark.parametrize(
    "url",
    [
        "http://adilet.zan.kz/rus/docs/Z100000274_",
        "https://adilet.zan.kz.evil.example/rus/docs/Z100000274_",
        "https://example.com/legal-summary",
    ],
)
def test_registry_rejects_non_https_or_unofficial_urls(url: str) -> None:
    registry = load_source_registry()
    payload = registry.model_dump(mode="json")
    payload["sources"][0]["official_url"] = url

    with pytest.raises(ValidationError, match="official HTTPS host"):
        SourceRegistry.model_validate(payload)


def test_registry_rejects_unknown_category() -> None:
    registry = load_source_registry()
    payload = registry.model_dump(mode="json")
    payload["sources"][0]["categories"] = ["immigration"]

    with pytest.raises(ValidationError):
        SourceRegistry.model_validate(payload)


def test_registry_rejects_source_that_is_not_allowlisted() -> None:
    registry = load_source_registry()
    payload = registry.model_dump(mode="json")
    payload["sources"][0]["is_allowlisted"] = False

    with pytest.raises(ValidationError, match="must remain allowlisted"):
        SourceRegistry.model_validate(payload)
