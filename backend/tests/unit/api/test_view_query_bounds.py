"""The `query` bound is enforced, not merely declared (spec 0035 AC-9, §5).

Spec 0035 §5 leans on this bound as its security argument — *"bounded twice,
`max_length` plus a character pattern at the endpoint"* — and until this file
existed nothing exercised either half. `QUERY_PATTERN` and `MAX_QUERY` could
both be deleted and the suite stayed green, which is the defect class
`.claude/rules/backend/testing.md` names: a documented property enforced by
nothing.

Mutation checked: drop `pattern=QUERY_PATTERN` from `TabOptions.query` and
`test_a_query_outside_the_declared_alphabet_is_rejected` goes red; raise
`MAX_QUERY` and `test_the_projection_enforces_the_length_bound_too` goes red.

The two halves are asserted separately on purpose. The endpoint's bound stops
a string before any projection sees it; the projection's own bound is what
protects `POST /v1/view-renders`, which forwards a dict and never passes
through `ViewQuery` at all.
"""

from typing import Final

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.presentation.activity_rows import ActivityOptions
from app.presentation.search import MAX_QUERY
from app.schemas.view_options_tabs import QUERY_PATTERN, TabOptions

VIEWS: Final[str] = "/v1/portfolios/current/views"
BATCH: Final[str] = "/v1/view-renders"
ACTIVITY: Final[str] = "activity.timeline.v1"
AUTH: Final[dict[str, str]] = {"Authorization": "Bearer good"}
UNPROCESSABLE: Final[int] = 422
OK: Final[int] = 200


def _status(client: TestClient, query: str) -> int:
    """Ask the live route for the Activity view with ``query``."""
    response = client.get(
        VIEWS, params={"view": ACTIVITY, "query": query}, headers=AUTH
    )
    return response.status_code


def test_a_query_inside_the_bound_is_served(views_client: TestClient) -> None:
    """The control: the rejections below are the bound, not everything 422ing."""
    assert _status(views_client, "nvda") == OK
    assert _status(views_client, "a" * MAX_QUERY) == OK


def test_a_query_over_the_length_bound_is_rejected(views_client: TestClient) -> None:
    """AC-9, one character past the declared maximum."""
    assert _status(views_client, "a" * (MAX_QUERY + 1)) == UNPROCESSABLE


@pytest.mark.parametrize(
    "query",
    ["nv%da", "nv/da", "nv<da", "nv\\da", "nv;da", "nv\nda"],
    ids=["percent", "slash", "angle", "backslash", "semicolon", "newline"],
)
def test_a_query_outside_the_declared_alphabet_is_rejected(
    views_client: TestClient, query: str
) -> None:
    """AC-9, the character half — the one §5 calls the alphabet bound."""
    assert _status(views_client, query) == UNPROCESSABLE


def test_the_endpoint_model_carries_both_halves_of_the_bound() -> None:
    """One pattern does both jobs, so deleting it is two red tests, not a diff."""
    assert str(MAX_QUERY) in QUERY_PATTERN
    with pytest.raises(ValidationError, match="should match pattern"):
        TabOptions(query="nv%da")
    with pytest.raises(ValidationError, match="should match pattern"):
        TabOptions(query="a" * (MAX_QUERY + 1))


def test_the_projection_enforces_the_length_bound_too() -> None:
    """`POST /v1/view-renders` forwards a dict; this is the only bound it meets."""
    assert ActivityOptions(query="a" * MAX_QUERY).needle == "a" * MAX_QUERY
    with pytest.raises(ValidationError, match="at most 24 characters"):
        ActivityOptions(query="a" * (MAX_QUERY + 1))


def test_the_batch_entry_rejects_an_over_long_query(views_client: TestClient) -> None:
    """Reached the way a batch reaches it: per-entry, not a whole-request 422."""
    response = views_client.post(
        BATCH,
        json={
            "renders": [{"view": ACTIVITY, "options": {"query": "a" * (MAX_QUERY + 1)}}]
        },
        headers=AUTH,
    )
    body = response.json()

    assert [entry["status"] for entry in body["results"]] == [UNPROCESSABLE], body
