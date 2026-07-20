import pytest

from bettercallsaul_api.evaluation import (
    EvaluationScenario,
    evaluate_retrieval,
    load_evaluation_scenarios,
    require_source_family_coverage,
)
from bettercallsaul_api.ingestion.models import CaseCategory
from bettercallsaul_api.retrieval import LegalSearchResult


def result(source_code: str, chunk_id: int) -> LegalSearchResult:
    return LegalSearchResult(
        chunk_id=chunk_id,
        provision_id=chunk_id,
        source_code=source_code,
        source_title=source_code,
        provision_code=f"article:{chunk_id}",
        heading=f"Статья {chunk_id}",
        content="Официальный текст.",
        official_url=f"https://adilet.zan.kz/rus/docs/{source_code}",
        revision_code="sha256:1234567890abcdef",
        effective_from=None,
        effective_to=None,
        score=0.1,
    )


class Retriever:
    def __init__(self, rows_by_query):
        self.rows_by_query = rows_by_query

    async def search(self, *, query_text, category, relevant_on, match_count):
        return tuple(self.rows_by_query[query_text])


@pytest.mark.asyncio
async def test_evaluation_computes_recall_and_reciprocal_rank() -> None:
    scenarios = (
        EvaluationScenario(
            scenario_id="charge-1",
            category=CaseCategory.CHARGE,
            query="списание",
            expected_source_codes=("payments_law", "payment_card_rules"),
        ),
        EvaluationScenario(
            scenario_id="product-1",
            category=CaseCategory.PRODUCT,
            query="брак",
            expected_source_codes=("consumer_protection_law",),
        ),
    )
    retriever = Retriever(
        {
            "списание": [result("civil_code_special", 1), result("payments_law", 2)],
            "брак": [result("consumer_protection_law", 3)],
        }
    )

    report = await evaluate_retrieval(retriever, scenarios, match_count=10)

    assert report.scenarios[0].recall_at_k == 0.5
    assert report.scenarios[0].reciprocal_rank == 0.5
    assert report.scenarios[1].recall_at_k == 1.0
    assert report.mean_recall_at_k == 0.75
    assert report.mean_reciprocal_rank == 0.75


@pytest.mark.asyncio
async def test_evaluation_reports_missing_required_source_family() -> None:
    scenario = EvaluationScenario(
        scenario_id="fine-1",
        category=CaseCategory.FINE,
        query="штраф",
        expected_source_codes=("administrative_offences_code",),
    )
    report = await evaluate_retrieval(
        Retriever({"штраф": [result("civil_code_special", 1)]}),
        (scenario,),
    )

    with pytest.raises(RuntimeError, match="administrative_offences_code"):
        require_source_family_coverage(report)


def test_bundled_evaluation_set_has_two_scenarios_per_category() -> None:
    scenarios = load_evaluation_scenarios()

    assert len(scenarios) == 10
    for category in CaseCategory:
        assert sum(item.category == category for item in scenarios) == 2
