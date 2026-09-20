"""Spec 0017 AC-5, AC-1, AC-10 — the card's contract with its consumers.

Split from ``test_scenario_comparison.py`` by the 150-line budget: that file
asserts the figures, this one asserts that every figure arrives pre-formatted,
that the A2UI adapter only binds what the payload already holds, and that the
projection reached the registry and the generated prompt.
"""

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import REGISTRY
from app.presentation.scenario_options import ScenarioComparisonOptions
from app.presentation.views.scenario_comparison import (
    PROJECTION,
    SUMMARY,
    VIEW_ID,
    ScenarioComparisonPayload,
    fitness,
    render,
    surface,
)


@pytest.fixture
def card(portfolio: Portfolio) -> ScenarioComparisonPayload:
    """The card the defaults render over the seeded portfolio."""
    return render(portfolio, ScenarioComparisonOptions())


def test_every_figure_the_reader_sees_is_a_display_string(
    card: ScenarioComparisonPayload,
) -> None:
    money = ("cost_basis", "realized_pl", "short_term_pl", "long_term_pl")
    body = card.model_dump(mode="json")
    numbers = [body["subject"]["price"], body["subject"]["proceeds"]]
    numbers += [body["spread"]["amount"]]
    for column in body["columns"]:
        numbers += [column[key] for key in money]
    assert len(numbers) == 3 + len(money) * len(card.columns)
    assert all(pair["display"].lstrip("+-").startswith("$") for pair in numbers)
    # ADR-K D-5: the exact Decimal travels *beside* the string, never instead.
    assert all(set(pair) == {"amount", "display"} for pair in numbers)
    assert body["subject"]["quantity_display"] == "0.18"


def test_the_surface_binds_the_payload_without_computing_anything(
    card: ScenarioComparisonPayload,
) -> None:
    rendered = surface(card)
    assert rendered.component == "ComparisonCard"
    assert rendered.view == VIEW_ID
    assert rendered.props["subject"]["symbol"] == "BTC"
    assert len(rendered.props["columns"]) == len(card.columns)
    assert rendered.props["spread"]["differs"] is True
    assert rendered.props["notes"] == [note.text for note in card.notes]


def test_the_card_is_never_auto_selected(portfolio: Portfolio) -> None:
    assert fitness(portfolio) == 0


def test_it_is_registered_and_reaches_the_catalog_and_the_prompt() -> None:
    assert REGISTRY.get(VIEW_ID) is PROJECTION
    assert PROJECTION.example["view"] == VIEW_ID
    assert f"- {VIEW_ID} — {SUMMARY}" in prompt_fragment(REGISTRY.all())
