"""Spec 0016 AC-6/AC-7 — what ``payoff.curve.v1`` accepts, and what it refuses.

An out-of-range option is a rejection, never a clamp and never a default
(ADR-K D-3). These assertions go through ``validated_options``, the one path
both the client and the model take.
"""

from typing import get_args

import pytest

from app.core.errors import ValidationFailedError
from app.domain.market import MARKET_REFERENCE
from app.domain.portfolio import Portfolio
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.payoff_order import PayoffCurveOptions, Symbol
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import REGISTRY
from app.presentation.resolve import validated_options
from app.presentation.selection import select_view
from app.presentation.views.payoff_curve import PROJECTION, VIEW_ID, fitness, render

ALLOCATION = "holdings.allocation.v1"


def test_the_registry_discovers_it_without_a_shared_list() -> None:
    """The one that goes red when ``register(...)`` is deleted."""
    assert REGISTRY.get(VIEW_ID) is PROJECTION
    assert PROJECTION.endpoints == PORTFOLIO_ENDPOINTS
    assert PROJECTION.example["view"] == VIEW_ID


def test_the_option_domain_is_exactly_the_curated_market_reference() -> None:
    """A ticker the backend cannot price is not an option the model may pick."""
    assert set(get_args(Symbol)) == {asset.symbol for asset in MARKET_REFERENCE}


def test_the_defaults_describe_a_renderable_order() -> None:
    filled = PayoffCurveOptions()

    assert (filled.symbol, filled.size, filled.size_in) == ("SOL", 500, "usd")
    assert (filled.side, filled.range_pct, filled.steps) == ("buy", 30, 12)


@pytest.mark.parametrize(
    ("supplied", "named"),
    [
        ({"symbol": "XXX"}, "symbol"),
        ({"symbol": "sol"}, "symbol"),
        ({"size": 0}, "size"),
        ({"size": 1_000_000_001}, "size"),
        ({"size_in": "eur"}, "size_in"),
        ({"side": "short"}, "side"),
        ({"range_pct": 4}, "range_pct"),
        ({"range_pct": 91}, "range_pct"),
        ({"steps": 0}, "steps"),
        ({"steps": 26}, "steps"),
        ({"precision": 99}, "precision"),
        ({"leverage": 3}, "leverage"),
    ],
    ids=[
        "unknown-ticker",
        "ticker-in-the-wrong-case",
        "empty-order",
        "size-over-the-cap",
        "unknown-size-unit",
        "unknown-side",
        "range-below-the-floor",
        "range-over-the-cap",
        "no-step-on-either-side",
        "steps-over-the-cap",
        "precision-out-of-range",
        "undeclared-option",
    ],
)
def test_a_rejected_option_is_never_a_default(
    supplied: dict[str, object], named: str
) -> None:
    with pytest.raises(ValidationFailedError, match=named):
        validated_options(PROJECTION, supplied)


def test_a_section_this_view_does_not_offer_is_refused(
    portfolio: Portfolio,
) -> None:
    options = PayoffCurveOptions(fields=("greeks",))

    with pytest.raises(ValidationFailedError, match="greeks"):
        render(portfolio, options)


def test_the_line_is_bounded_by_the_step_limit(portfolio: Portfolio) -> None:
    """25 steps a side is 51 points — the largest line any option can ask for."""
    payload = render(portfolio, PayoffCurveOptions(steps=25))

    assert len(payload.series[0].points) == 51


def test_the_same_options_twice_give_the_same_payload(portfolio: Portfolio) -> None:
    options = PayoffCurveOptions(symbol="LINK", range_pct=5, steps=25, side="sell")

    first = render(portfolio, options)
    second = render(portfolio, options)

    assert first.model_dump(mode="json") == second.model_dump(mode="json")


def test_the_generated_prompt_teaches_every_bound_truthfully() -> None:
    """The model is taught the option domain, not a shape it has to guess."""
    text = prompt_fragment(REGISTRY.all())

    assert f"- {VIEW_ID} — {PROJECTION.summary}" in text
    assert "symbol (one of 'AAVE'" in text
    assert "size (integer 1..1000000000)" in text
    assert "size_in (one of 'units', 'usd')" in text
    assert "side (one of 'buy', 'sell')" in text
    assert "range_pct (integer 5..90)" in text
    assert "steps (integer 1..25)" in text


@pytest.mark.parametrize(
    "holdings", ["portfolio", "winners_only", "empty_portfolio"], ids=str
)
def test_the_selection_rule_never_reaches_for_it(
    holdings: str, request: pytest.FixtureRequest
) -> None:
    subject: Portfolio = request.getfixturevalue(holdings)

    chosen = select_view(subject, projections=REGISTRY.all(), default=ALLOCATION)

    assert fitness(subject) == 0
    assert chosen != VIEW_ID
