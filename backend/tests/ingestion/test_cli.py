import pytest

from bettercallsaul_api.ingestion.cli import parse_args, select_sources
from bettercallsaul_api.ingestion.source_registry import load_source_registry


def test_cli_selects_one_registry_source_by_stable_code() -> None:
    args = parse_args(["--source", "payments_law", "--activate"])

    selected = select_sources(load_source_registry(), args)

    assert [source.source_code for source in selected] == ["payments_law"]
    assert args.activate is True
    assert args.dry_run is False


def test_cli_all_mode_uses_every_curated_source_for_dry_run() -> None:
    args = parse_args(["--all", "--dry-run"])

    selected = select_sources(load_source_registry(), args)

    assert len(selected) == 8
    assert args.dry_run is True


def test_cli_rejects_unknown_source_code_without_accepting_a_url() -> None:
    args = parse_args(["--source", "https://evil.example/law"])

    with pytest.raises(ValueError, match="Unknown source code"):
        select_sources(load_source_registry(), args)


@pytest.mark.parametrize(
    "arguments",
    [
        [],
        ["--all", "--source", "payments_law"],
        ["--all", "--dry-run", "--activate"],
    ],
)
def test_cli_rejects_ambiguous_modes(arguments: list[str]) -> None:
    with pytest.raises(SystemExit):
        parse_args(arguments)
