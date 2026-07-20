from datetime import date
from importlib import resources
from statistics import fmean
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

from bettercallsaul_api.ingestion.models import CaseCategory
from bettercallsaul_api.retrieval import LegalSearchResult


class EvaluationScenario(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    scenario_id: str
    category: CaseCategory
    query: str = Field(min_length=3)
    expected_source_codes: tuple[str, ...] = Field(min_length=1)


class ScenarioEvaluation(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    scenario_id: str
    expected_source_codes: tuple[str, ...]
    retrieved_source_codes: tuple[str, ...]
    recall_at_k: float
    reciprocal_rank: float


class RetrievalEvaluationReport(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    match_count: int
    scenarios: tuple[ScenarioEvaluation, ...]
    mean_recall_at_k: float
    mean_reciprocal_rank: float


class EvaluatedRetriever(Protocol):
    async def search(
        self,
        *,
        query_text: str,
        category: CaseCategory,
        relevant_on: date,
        match_count: int,
    ) -> tuple[LegalSearchResult, ...]: ...


def load_evaluation_scenarios() -> tuple[EvaluationScenario, ...]:
    raw = (
        resources.files("bettercallsaul_api")
        .joinpath("kz_legal_retrieval_v1.json")
        .read_text(encoding="utf-8")
    )
    return tuple(TypeAdapter(list[EvaluationScenario]).validate_json(raw))


async def evaluate_retrieval(
    retriever: EvaluatedRetriever,
    scenarios: tuple[EvaluationScenario, ...],
    *,
    match_count: int = 10,
    relevant_on: date | None = None,
) -> RetrievalEvaluationReport:
    evaluation_date = relevant_on or date.today()
    evaluated: list[ScenarioEvaluation] = []
    for scenario in scenarios:
        rows = await retriever.search(
            query_text=scenario.query,
            category=scenario.category,
            relevant_on=evaluation_date,
            match_count=match_count,
        )
        retrieved_codes = tuple(row.source_code for row in rows)
        unique_retrieved = set(retrieved_codes)
        expected = set(scenario.expected_source_codes)
        recall = len(expected & unique_retrieved) / len(expected)
        reciprocal_rank = 0.0
        for rank, source_code in enumerate(retrieved_codes, start=1):
            if source_code in expected:
                reciprocal_rank = 1.0 / rank
                break
        evaluated.append(
            ScenarioEvaluation(
                scenario_id=scenario.scenario_id,
                expected_source_codes=scenario.expected_source_codes,
                retrieved_source_codes=retrieved_codes,
                recall_at_k=recall,
                reciprocal_rank=reciprocal_rank,
            )
        )

    return RetrievalEvaluationReport(
        match_count=match_count,
        scenarios=tuple(evaluated),
        mean_recall_at_k=fmean(item.recall_at_k for item in evaluated),
        mean_reciprocal_rank=fmean(item.reciprocal_rank for item in evaluated),
    )


def require_source_family_coverage(report: RetrievalEvaluationReport) -> None:
    expected = {
        source_code
        for scenario in report.scenarios
        for source_code in scenario.expected_source_codes
    }
    retrieved = {
        source_code
        for scenario in report.scenarios
        for source_code in scenario.retrieved_source_codes
    }
    missing = sorted(expected - retrieved)
    if missing:
        raise RuntimeError(
            "Required source families were not retrieved: " + ", ".join(missing)
        )

