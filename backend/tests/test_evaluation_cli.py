import pytest

from bettercallsaul_api.evaluation_cli import parse_args


def test_evaluation_cli_accepts_bounded_match_count() -> None:
    assert parse_args([]).match_count == 10
    assert parse_args(["--match-count", "25"]).match_count == 25


@pytest.mark.parametrize("value", ["0", "51", "not-a-number"])
def test_evaluation_cli_rejects_invalid_match_count(value: str) -> None:
    with pytest.raises(SystemExit):
        parse_args(["--match-count", value])
