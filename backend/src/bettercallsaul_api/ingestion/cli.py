import argparse
import asyncio
import json
from collections.abc import Sequence

import httpx

from bettercallsaul_api.config import Settings
from bettercallsaul_api.ingestion.chunker import LegalHierarchyChunker
from bettercallsaul_api.ingestion.embeddings import GeminiEmbeddingClient
from bettercallsaul_api.ingestion.fetcher import (
    OfficialSourceFetcher,
    build_system_ssl_context,
)
from bettercallsaul_api.ingestion.models import SourceDefinition, SourceRegistry
from bettercallsaul_api.ingestion.parser import LegalSourceParser
from bettercallsaul_api.ingestion.pipeline import (
    LegalIngestionPipeline,
    preview_source,
)
from bettercallsaul_api.ingestion.source_registry import load_source_registry
from bettercallsaul_api.supabase_gateway import SupabaseGateway


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bettercallsaul-ingest",
        description="Ingest curated official Kazakhstan legal sources.",
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--source", help="Stable source code from the registry.")
    target.add_argument("--all", action="store_true", help="Process all sources.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch, parse, and chunk without AI or database writes.",
    )
    mode.add_argument(
        "--activate",
        action="store_true",
        help="Activate only after all database validation succeeds.",
    )
    return parser


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    return build_argument_parser().parse_args(arguments)


def select_sources(
    registry: SourceRegistry,
    args: argparse.Namespace,
) -> tuple[SourceDefinition, ...]:
    if args.all:
        return registry.sources
    selected = tuple(
        source for source in registry.sources if source.source_code == args.source
    )
    if not selected:
        raise ValueError("Unknown source code.")
    return selected


async def run_cli(args: argparse.Namespace) -> list[dict[str, object]]:
    registry = load_source_registry()
    sources = select_sources(registry, args)
    settings = Settings()
    async with httpx.AsyncClient(verify=build_system_ssl_context()) as client:
        fetcher = OfficialSourceFetcher(client)
        parser = LegalSourceParser()
        chunker = LegalHierarchyChunker()
        if args.dry_run:
            results = [
                await preview_source(
                    source,
                    fetcher=fetcher,
                    parser=parser,
                    chunker=chunker,
                )
                for source in sources
            ]
        else:
            embedder = GeminiEmbeddingClient(settings, client)
            gateway = SupabaseGateway(settings, client)
            pipeline = LegalIngestionPipeline(
                fetcher=fetcher,
                parser=parser,
                chunker=chunker,
                embedder=embedder,
                gateway=gateway,
                embedding_model=settings.gemini_embedding_model,
            )
            results = [
                await pipeline.ingest(source, activate=args.activate)
                for source in sources
            ]
    return [result.model_dump(mode="json") for result in results]


def main(arguments: Sequence[str] | None = None) -> None:
    args = parse_args(arguments)
    results = asyncio.run(run_cli(args))
    print(json.dumps(results, ensure_ascii=False, indent=2))
