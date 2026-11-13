"""Spec 0058 AC-12 — the alerts read the fields this code writes.

``infra/gemini_spend.tf`` filters ``agent.turn`` by field names and an outcome
string that are declared, independently, in Python. Two declarations of one
fact get a test comparing them (``testing.md``): rename the log field here and
the metric would extract nothing, silently, while both halves looked fine.
``terraform validate`` cannot read Python and ``make gate`` cannot read HCL,
so the comparison lives in the gate that changes most often — and
``backend-ci`` watches ``infra/gemini_spend.tf`` for the same reason.
"""

import re
from datetime import date
from pathlib import Path

from app.agent.contracts import TurnState
from app.core.model_errors import MODEL_OUT_OF_CREDIT
from app.services.agent_telemetry import COST_FIELD, TURN_METRIC, cost_fields

SPEND_TF = Path(__file__).resolve().parents[4] / "infra" / "gemini_spend.tf"


def hcl() -> str:
    """Return the Terraform file, failing loudly when it has moved."""
    assert SPEND_TF.is_file(), f"{SPEND_TF} is gone — the alerts read nothing"
    return SPEND_TF.read_text(encoding="utf-8")


def local_value(name: str) -> str:
    """Return the string a ``locals`` entry is set to, or fail naming it."""
    found = re.search(rf'^\s*{name}\s*=\s*"([^"]+)"', hcl(), re.MULTILINE)
    assert found, f"local `{name}` is not declared in {SPEND_TF.name}"
    return found.group(1)


def test_the_metric_extracts_the_field_the_turn_logs() -> None:
    assert local_value("gemini_cost_field") == COST_FIELD
    assert "EXTRACT(jsonPayload.${local.gemini_cost_field})" in hcl()


def test_the_out_of_credit_alert_matches_the_outcome_the_turn_records() -> None:
    assert local_value("gemini_out_of_credit") == MODEL_OUT_OF_CREDIT


def test_every_turn_field_the_terraform_filters_on_is_one_the_turn_logs() -> None:
    logged = {"event", "outcome", *cost_fields(TurnState(), model="m", on=date.min)}
    filtered = set(re.findall(r"jsonPayload\.([a-z_]+)", hcl()))

    assert filtered, "no jsonPayload field found — the check would be vacuous"
    assert filtered <= logged, filtered - logged
    assert f'jsonPayload.event=\\"{TURN_METRIC}\\"' in hcl()
