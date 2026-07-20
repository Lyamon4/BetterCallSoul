import hashlib
import re

from bs4 import BeautifulSoup, Tag

from bettercallsaul_api.ingestion.models import (
    FetchedDocument,
    ParsedProvision,
    ParsedRevision,
    ParserKind,
    SourceDefinition,
)


PARSER_VERSION = "legal-html-v1"
ARTICLE_PATTERN = re.compile(r"^Статья\s+([0-9]+(?:-[0-9]+)*)\.\s*(.*)$", re.I)
NUMBERED_PARAGRAPH_PATTERN = re.compile(r"^([0-9]+(?:-[0-9]+)*)\.\s+(.+)$")


class SourceParseError(RuntimeError):
    pass


def normalize_text(value: str) -> str:
    return " ".join(value.replace("\xa0", " ").split())


class LegalSourceParser:
    def parse(
        self,
        source: SourceDefinition,
        document: FetchedDocument,
    ) -> ParsedRevision:
        if document.status != "fetched" or not document.body or not document.content_checksum:
            raise SourceParseError("Official source could not be parsed.")
        try:
            if source.parser == ParserKind.ADILET:
                provisions = self._parse_adilet(source, document.body)
            else:
                provisions = self._parse_guidance(source, document.body)
        except (AttributeError, TypeError, ValueError) as error:
            raise SourceParseError("Official source could not be parsed.") from error

        if not provisions:
            raise SourceParseError("Official source could not be parsed.")

        normalized_text = "\n\n".join(
            f"{provision.heading}\n" + "\n".join(provision.paragraphs)
            for provision in provisions
        )
        return ParsedRevision(
            source_code=source.source_code,
            revision_code=f"sha256:{document.content_checksum[:16]}",
            effective_from=source.adopted_on,
            content_checksum=document.content_checksum,
            parser_version=PARSER_VERSION,
            normalized_text=normalized_text,
            provisions=tuple(provisions),
        )

    def _parse_adilet(
        self,
        source: SourceDefinition,
        html: str,
    ) -> list[ParsedProvision]:
        soup = BeautifulSoup(html, "html.parser")
        article = soup.find("article")
        if not isinstance(article, Tag):
            return []

        provisions = self._parse_adilet_articles(source, article)
        if provisions:
            return provisions
        return self._parse_adilet_numbered_paragraphs(source, article)

    def _parse_adilet_articles(
        self,
        source: SourceDefinition,
        article: Tag,
    ) -> list[ParsedProvision]:
        provisions: list[ParsedProvision] = []
        current_chapter = source.title
        current_heading: str | None = None
        current_code: str | None = None
        current_anchor: str | None = None
        current_paragraphs: list[str] = []

        def flush() -> None:
            nonlocal current_heading, current_code, current_anchor, current_paragraphs
            if not current_heading or not current_code or not current_paragraphs:
                current_heading = None
                current_code = None
                current_anchor = None
                current_paragraphs = []
                return
            content = "\n".join(current_paragraphs)
            provisions.append(
                ParsedProvision(
                    provision_code=current_code,
                    heading=current_heading,
                    hierarchy_path=current_chapter,
                    paragraphs=tuple(current_paragraphs),
                    source_anchor=current_anchor,
                    categories=source.categories,
                    sectors=source.sectors,
                    content_checksum=hashlib.sha256(content.encode("utf-8")).hexdigest(),
                )
            )
            current_heading = None
            current_code = None
            current_anchor = None
            current_paragraphs = []

        for node in article.find_all(["h2", "h3", "p"]):
            text = normalize_text(node.get_text(" ", strip=True))
            if not text:
                continue
            classes = set(node.get("class", []))
            if "note" in classes or text.casefold().startswith(("сноска.", "примечание")):
                continue
            article_match = ARTICLE_PATTERN.match(text)
            if article_match:
                flush()
                article_number = article_match.group(1)
                current_code = f"article:{article_number}"
                current_heading = text
                anchor = node.find("a", attrs={"name": True})
                anchor_value = anchor.get("name") if isinstance(anchor, Tag) else node.get("id")
                current_anchor = f"#{anchor_value}" if anchor_value else None
                continue
            if node.name in {"h2", "h3"}:
                current_chapter = text
                continue
            if current_heading:
                current_paragraphs.append(text)

        flush()
        return provisions

    def _parse_adilet_numbered_paragraphs(
        self,
        source: SourceDefinition,
        article: Tag,
    ) -> list[ParsedProvision]:
        provisions: list[ParsedProvision] = []
        current_chapter = source.title
        current_hierarchy: str | None = None
        current_number: str | None = None
        current_anchor: str | None = None
        current_paragraphs: list[str] = []

        def flush() -> None:
            nonlocal current_hierarchy, current_number, current_anchor, current_paragraphs
            if not current_number or not current_paragraphs:
                current_number = None
                current_hierarchy = None
                current_anchor = None
                current_paragraphs = []
                return
            content = "\n".join(current_paragraphs)
            hierarchy = current_hierarchy or source.title
            stable_id = current_anchor.removeprefix("#") if current_anchor else (
                f"{current_number}-{hashlib.sha256(hierarchy.encode('utf-8')).hexdigest()[:8]}"
            )
            provisions.append(
                ParsedProvision(
                    provision_code=f"paragraph:{stable_id}",
                    heading=f"Пункт {current_number}",
                    hierarchy_path=hierarchy,
                    paragraphs=tuple(current_paragraphs),
                    source_anchor=current_anchor,
                    categories=source.categories,
                    sectors=source.sectors,
                    content_checksum=hashlib.sha256(content.encode("utf-8")).hexdigest(),
                )
            )
            current_number = None
            current_hierarchy = None
            current_anchor = None
            current_paragraphs = []

        for node in article.find_all(["h2", "h3", "p"]):
            text = normalize_text(node.get_text(" ", strip=True))
            if not text:
                continue
            classes = set(node.get("class", []))
            if "note" in classes or text.casefold().startswith(("сноска.", "примечание")):
                continue
            if node.name in {"h2", "h3"}:
                current_chapter = text
                continue
            paragraph_match = NUMBERED_PARAGRAPH_PATTERN.match(text)
            if paragraph_match:
                flush()
                current_number = paragraph_match.group(1)
                current_hierarchy = current_chapter
                anchor_value = node.get("id")
                anchor = node.find("a", attrs={"name": True})
                if isinstance(anchor, Tag):
                    anchor_value = anchor.get("name") or anchor_value
                current_anchor = f"#{anchor_value}" if anchor_value else None
                current_paragraphs = [text]
                continue
            if current_number:
                current_paragraphs.append(text)

        flush()
        return provisions

    def _parse_guidance(
        self,
        source: SourceDefinition,
        html: str,
    ) -> list[ParsedProvision]:
        soup = BeautifulSoup(html, "html.parser")
        heading_node = soup.find("h1") or soup.find("h2")
        if not isinstance(heading_node, Tag):
            return []
        root: Tag | None = None
        candidate = heading_node.parent
        while isinstance(candidate, Tag):
            if len(candidate.find_all(["p", "li"])) >= 2:
                root = candidate
                break
            candidate = candidate.parent
        if root is None:
            return []
        for unwanted in root.find_all(["script", "style", "nav", "footer", "header"]):
            unwanted.decompose()
        heading = normalize_text(heading_node.get_text(" ", strip=True))
        paragraphs = tuple(
            text
            for node in root.find_all(["p", "li"])
            if (text := normalize_text(node.get_text(" ", strip=True)))
        )
        if len(paragraphs) < 2:
            return []
        content = "\n".join(paragraphs)
        return [
            ParsedProvision(
                provision_code="guidance:main",
                heading=heading,
                hierarchy_path=source.title,
                paragraphs=paragraphs,
                source_anchor=None,
                categories=source.categories,
                sectors=source.sectors,
                content_checksum=hashlib.sha256(content.encode("utf-8")).hexdigest(),
            )
        ]
