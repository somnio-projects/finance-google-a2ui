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
        "BTC:1,BTC:2",
        "btc:1",
        "BTC:1.123456789",
        "BTC:1,ETH:1,SOL:1,ARB:1,AAVE:1,LINK:1",
        "",
    ],
    ids=["unknown", "repeated", "lowercase", "nine-decimals", "six-legs", "empty"],
)
def test_a_value_outside_the_bound_is_a_422_naming_the_option(legs: str) -> None:
    """AC-4 — the pattern and the parser refuse together, as one option."""
    with pytest.raises(ValidationFailedError, match=r"rejected option\(s\) \['legs'\]"):
        validated_options(REGISTRY.get(VIEW_ID), {"legs": legs})


def test_an_undeclared_option_is_refused_rather_than_ignored() -> None:
    with pytest.raises(ValidationFailedError, match="rejected option"):
        validated_options(REGISTRY.get(VIEW_ID), {"quantity_btc": "3"})


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
    """OD-3 — null at zero units and at the published ceiling."""
    empty = render(portfolio, OrderTicketV2Options(legs="BTC:0"))
    # ARB at the ceiling rather than BTC: a billion units of a 64-thousand
    # dollar coin is a portfolio weight of 13 billion per cent, and the
    # `display` bound refuses the string before the stepper can be asserted.
    full = render(portfolio, OrderTicketV2Options(legs=f"ARB:{MAX_LEG_QUANTITY}"))

    assert empty.title == "Draft order · Buy · 1 leg"
    assert (empty.lines[0].decrement, empty.lines[0].increment) == (None, "BTC:0.01")
    assert empty.lines[0].weight.display == "0.00%"
    assert empty.impact.total.amount.display == "$0.00"
    assert full.lines[0].increment is None


def test_legs_on_one_chain_are_weighed_as_one_group(
    portfolio: Portfolio,
) -> None:
    """OD-5 — LINK and ARB settle on Ethereum, so they fold into one row.

    The stablecoin is the leg with no ecosystem, and
    `test_draft_weights.py` covers the fall back to its asset class.
    """
    payload = render(portfolio, OrderTicketV2Options(legs="LINK:10,ARB:100"))

    assert [
        (shift.label, shift.before.display, shift.after.display)
        for shift in payload.impact.weight_shifts
    ] == [("Portfolio weight · Ethereum", "49.49%", "49.56%")]
