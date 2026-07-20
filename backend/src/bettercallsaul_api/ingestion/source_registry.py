from importlib import resources

from bettercallsaul_api.ingestion.models import SourceRegistry


def load_source_registry() -> SourceRegistry:
    raw_registry = (
        resources.files("bettercallsaul_api.ingestion")
        .joinpath("sources.json")
        .read_text(encoding="utf-8")
    )
    return SourceRegistry.model_validate_json(raw_registry)

