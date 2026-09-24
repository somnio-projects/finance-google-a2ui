"""Spec 0031 AC-3/AC-4 — the ``legs`` option: its bound, and the stepper.

Rejections go through ``validated_options`` — the call both the HTTP path and
the render-intent path make — so a refused value is a 422 naming the option,
on both paths, never a clamp (ADR-K D-3, D-11).
"""

import pytest

from app.core.errors import ValidationFailedError
from app.domain.draft_legs import LEGS_PATTERN, MAX_LEG_QUANTITY
from app.domain.portfolio import Portfolio
from app.presentation.registry import REGISTRY
from app.presentation.resolve import validated_options
from app.presentation.views.order_ticket_v2 import (
    VIEW_ID,
    OrderTicketV2Options,
    render,
)
from app.schemas import view_options


def test_the_query_model_carries_the_domains_pattern_verbatim() -> None:
    """Two declarations of one bound, compared rather than trusted."""
    assert view_options.LEGS_PATTERN == LEGS_PATTERN


@pytest.mark.parametrize(
    "legs",
    [
        "XRP:1",
        "NVDA:1,NVDA:2",
        "nvda:1",
        "NVDA:1.5",
        "NVDA:1,AVGO:1,AMD:1,AAPL:1,MSFT:1,PG:1",
        "",
    ],
    ids=["unknown", "repeated", "lowercase", "fractional", "six-legs", "empty"],
)
def test_a_value_outside_the_bound_is_a_422_naming_the_option(legs: str) -> None:
    """AC-4 — the pattern and the parser refuse together, as one option."""
    with pytest.raises(ValidationFailedError, match=r"rejected option\(s\) \['legs'\]"):
        validated_options(REGISTRY.get(VIEW_ID), {"legs": legs})


def test_an_undeclared_option_is_refused_rather_than_ignored() -> None:
    with pytest.raises(ValidationFailedError, match="rejected option"):
        validated_options(REGISTRY.get(VIEW_ID), {"quantity_nvda": "3"})


def test_every_stepper_value_a_line_carries_is_accepted_back(
    portfolio: Portfolio,
) -> None:
    """OD-3 — the option value a tap sends is one the options model takes."""
    payload = render(portfolio, OrderTicketV2Options())
    projection = REGISTRY.get(VIEW_ID)

    for line in payload.lines:
        for value in (line.increment, line.decrement):
            assert value is not None
            accepted = validated_options(projection, {"legs": value})
            assert isinstance(accepted, OrderTicketV2Options)
            assert accepted.legs == value


def test_a_stepper_at_the_bound_is_disabled_rather_than_refused(
    portfolio: Portfolio,
) -> None:
    """OD-3 — null at zero shares and at the six-digit ceiling."""
    empty = render(portfolio, OrderTicketV2Options(legs="NVDA:0"))
    full = render(portfolio, OrderTicketV2Options(legs=f"NVDA:{MAX_LEG_QUANTITY}"))

    assert empty.title == "Draft order · Buy · 1 leg"
    assert (empty.lines[0].decrement, empty.lines[0].increment) == (None, "NVDA:1")
    assert empty.lines[0].weight.display == "0.00%"
    assert empty.impact.total.amount.display == "$0.00"
    assert full.lines[0].increment is None


def test_a_leg_without_a_sector_is_weighed_under_its_asset_class(
    portfolio: Portfolio,
) -> None:
    """OD-5 — bonds and gold get a row each; none is silently dropped."""
    payload = render(portfolio, OrderTicketV2Options(legs="BND:10,GLD:1"))

    assert [
        (shift.label, shift.before.display, shift.after.display)
        for shift in payload.impact.weight_shifts
    ] == [
        ("Portfolio weight · Bonds", "18.00%", "18.15%"),
        ("Portfolio weight · Alternatives", "12.00%", "12.04%"),
    ]
