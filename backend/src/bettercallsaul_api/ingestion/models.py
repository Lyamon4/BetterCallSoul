from datetime import date
from enum import StrEnum
from typing import Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, model_validator


OFFICIAL_SOURCE_HOSTS = frozenset(
    {
        "adilet.zan.kz",
        "www.adilet.zan.kz",
        "egov.kz",
        "www.gov.kz",
    }
)


class CaseCategory(StrEnum):
    CHARGE = "charge"
    FINE = "fine"
    SUBSCRIPTION = "subscription"
    PRODUCT = "product"
    BILL = "bill"


class ParserKind(StrEnum):
    ADILET = "adilet"
    OFFICIAL_GUIDANCE = "official_guidance"


class SourceDefinition(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    source_code: str = Field(pattern=r"^[a-z][a-z0-9_]+$")
    title: str = Field(min_length=3)
    authority: str = Field(min_length=3)
    official_url: str
    document_type: str = Field(min_length=2)
    parser: ParserKind
    categories: tuple[CaseCategory, ...] = Field(min_length=1)
    sectors: tuple[str, ...] = ()
    adopted_on: date | None = None
    language: str = Field(default="ru", pattern=r"^(ru|kk)$")
    jurisdiction: str = Field(default="KZ", pattern=r"^KZ$")
    is_allowlisted: bool = True

    @model_validator(mode="after")
    def validate_official_source(self) -> "SourceDefinition":
        parsed = urlsplit(self.official_url)
        if (
            parsed.scheme != "https"
            or parsed.hostname not in OFFICIAL_SOURCE_HOSTS
            or parsed.username is not None
            or parsed.password is not None
            or parsed.port is not None
        ):
            raise ValueError("source must use an official HTTPS host")
        if not self.is_allowlisted:
            raise ValueError("curated sources must remain allowlisted")
        return self


class SourceRegistry(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    version: int = Field(ge=1)
    sources: tuple[SourceDefinition, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_uniqueness(self) -> "SourceRegistry":
        codes = [source.source_code for source in self.sources]
        if len(codes) != len(set(codes)):
            raise ValueError("source_code values must be unique")
        urls = [source.official_url for source in self.sources]
        if len(urls) != len(set(urls)):
            raise ValueError("official_url values must be unique")
        return self


class FetchedDocument(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    status: Literal["fetched", "unchanged"]
    requested_url: str
    final_url: str
    body: str | None
    content_checksum: str | None
    etag: str | None
    last_modified: str | None

    @model_validator(mode="after")
    def validate_fetch_state(self) -> "FetchedDocument":
        if self.status == "fetched" and (
            self.body is None or self.content_checksum is None
        ):
            raise ValueError("fetched documents require body and checksum")
        if self.status == "unchanged" and (
            self.body is not None or self.content_checksum is not None
        ):
            raise ValueError("unchanged documents cannot contain a body")
        return self


class ParsedProvision(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    provision_code: str = Field(min_length=3)
    heading: str = Field(min_length=3)
    hierarchy_path: str = Field(min_length=1)
    paragraphs: tuple[str, ...] = Field(min_length=1)
    source_anchor: str | None = None
    categories: tuple[CaseCategory, ...] = Field(min_length=1)
    sectors: tuple[str, ...] = ()
    content_checksum: str = Field(pattern=r"^[a-f0-9]{64}$")


class ParsedRevision(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    source_code: str
    revision_code: str
    effective_from: date | None
    effective_to: date | None = None
    content_checksum: str = Field(pattern=r"^[a-f0-9]{64}$")
    parser_version: str
    normalized_text: str = Field(min_length=1)
    provisions: tuple[ParsedProvision, ...] = Field(min_length=1)
