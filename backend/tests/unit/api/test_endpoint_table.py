"""The human-facing endpoint table, and that the checked-in one is current.

`backend/docs/ENDPOINTS.md` is generated from the same document `/openapi.json`
serves (spec 0038 OD-4). `make openapi-check` re-renders and diffs it; this
asserts the same property from inside the suite, so a stale table fails the
tests too and not only the gate step.
"""

from pathlib import Path

from fastapi import FastAPI

from app.api.endpoint_table import (
    ENDPOINTS_PATH,
    FIX_COMMAND,
    endpoint_table,
    references,
)
from app.api.route_facts import route_facts

REPO_ROOT = Path(__file__).resolve().parents[4]


def test_a_description_that_names_nothing_renders_a_dash() -> None:
    assert references("Reads one thing.") == "—"


def test_spec_numbers_and_adrs_are_listed_once_in_order() -> None:
    named = "Spec 0027 AC-3, ADR-B D-12, spec 0027 again, ADR-B once more."
    assert references(named) == "0027, ADR-B"


def test_one_row_per_operation_in_route_order(app: FastAPI) -> None:
    found = route_facts(app)
    rendered = endpoint_table(app.openapi(), found)
    rows = [line for line in rendered.splitlines() if line.startswith("| `")]
    assert len(rows) == len(found)
    assert rows[0].startswith("| `GET` | `/health` | public |")


def test_a_row_names_the_auth_and_the_flag(app: FastAPI) -> None:
    rendered = endpoint_table(app.openapi(), route_facts(app))
    assert "| `GET` | `/v1/me/audit-events` | bearer | `identity.audit` |" in rendered
    assert "| `GET` | `/v1/me` | bearer | — |" in rendered


def test_the_table_says_how_to_regenerate_itself(app: FastAPI) -> None:
    assert FIX_COMMAND in endpoint_table(app.openapi(), route_facts(app))


def test_the_checked_in_table_is_current(app: FastAPI) -> None:
    generated = endpoint_table(app.openapi(), route_facts(app))
    checked_in = (REPO_ROOT / ENDPOINTS_PATH).read_text(encoding="utf-8")
    assert checked_in == generated, f"stale — regenerate with `{FIX_COMMAND}`"
