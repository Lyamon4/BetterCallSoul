import argparse
import asyncio
import json
from collections.abc import Sequence

import httpx

from bettercallsaul_api.config import Settings
from bettercallsaul_api.evaluation import (
    evaluate_retrieval,
    load_evaluation_scenarios,
    require_source_family_coverage,
)
from bettercallsaul_api.ingestion.embeddings import GeminiEmbeddingClient
from bettercallsaul_api.ingestion.fetcher import build_system_ssl_context
from bettercallsaul_api.retrieval import LegalRetriever
from bettercallsaul_api.supabase_gateway import SupabaseGateway


def bounded_match_count(value: str) -> int:
    parsed = int(value)
    if parsed < 1 or parsed > 50:
        raise argparse.ArgumentTypeError("match count must be between 1 and 50")
    return parsed


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="bettercallsaul-evaluate",
        description="Evaluate protected hybrid retrieval against reviewed scenarios.",
    )
    parser.add_argument(
        "--match-count",
        type=bounded_match_count,
        default=10,
    )
    return parser.parse_args(arguments)


async def run_evaluation(match_count: int) -> dict[str, object]:
    settings = Settings()
    async with httpx.AsyncClient(verify=build_system_ssl_context()) as client:
        embedder = GeminiEmbeddingClient(settings, client)
        gateway = SupabaseGateway(settings, client)
        retriever = LegalRetriever(embedder, gateway)
        report = await evaluate_retrieval(
            retriever,
            load_evaluation_scenarios(),
            match_count=match_count,
        )
    require_source_family_coverage(report)
    return report.model_dump(mode="json")


def main(arguments: Sequence[str] | None = None) -> None:
    args = parse_args(arguments)
    report = asyncio.run(run_evaluation(args.match_count))
    print(json.dumps(report, ensure_ascii=False, indent=2))
