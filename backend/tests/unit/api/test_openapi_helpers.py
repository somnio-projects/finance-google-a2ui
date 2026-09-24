"""The builder that fills the document, tested apart from the document.

`api/openapi.py` owns the one `responses=` block every controller reuses
(`api-design.md` §3: copy-pasting it into two controllers is a review
blocker). These two tests are about that builder; the assertions over the
rendered document are in `test_openapi_contract.py`, which is where they were
until the contract file reached its 150-line budget.
"""

import pytest

from app.api.openapi import PROBLEM_DESCRIPTIONS, problem_responses


def test_problem_responses_are_built_from_one_place() -> None:
    built = problem_responses(401, 503)
    assert set(built) == {401, 503}
    assert built[401]["description"] == PROBLEM_DESCRIPTIONS[401]
    assert built[401]["model"].__name__ == "ProblemDetails"
    example = built[503]["content"]["application/problem+json"]["example"]
    assert example["type"] == "https://errors.finance-a2ui/dependency-unavailable"
    assert example["status"] == 503


def test_problem_responses_rejects_an_undocumented_status() -> None:
    with pytest.raises(KeyError, match="418"):
        problem_responses(418)
