"""Spec 0031, re-based by 0044 — a vague intent becomes legs here, never in
the model.

The design's own prompt — *put about $10k into the majors* — must compose the
three legs the design draws, at the seeded prices, floored to each asset's
step. That composition is what `order.ticket.v2` defaults to, so the two are
compared.
"""

from decimal import Decimal
from typing import get_args

import pytest

from app.domain.baskets import CURATED, Basket, basket_legs, basket_weights
from app.domain.draft_legs import LegRequest, format_legs
from app.domain.market import MARKET_REFERENCE
from app.domain.money import ZERO
from app.presentation.order_ticket_v2_options import DEFAULT_LEGS

BASKETS = get_args(Basket)
TEN_THOUSAND = Decimal(10000)


def test_majors_composes_the_design_legs_on_each_assets_step() -> None:
    """AC-7 — 40 / 35 / 25 of $10k at the seeded prices, floored to the step."""
    legs = basket_legs("majors", TEN_THOUSAND)

    assert legs == (
        LegRequest(symbol="BTC", quantity=Decimal("0.06")),
        LegRequest(symbol="ETH", quantity=Decimal("1.0")),
        LegRequest(symbol="SOL", quantity=Decimal("16")),
    )


def test_the_ticket_defaults_to_what_the_design_prompt_composes() -> None:
    """Two declarations of one fact, compared instead of trusted."""
    assert format_legs(basket_legs("majors", TEN_THOUSAND)) == DEFAULT_LEGS


def test_the_curated_weights_are_the_designs() -> None:
    assert CURATED["majors"] == (
        ("BTC", Decimal("0.40")),
        ("ETH", Decimal("0.35")),
        ("SOL", Decimal("0.25")),
    )


@pytest.mark.parametrize("basket", BASKETS, ids=BASKETS)
def test_every_basket_has_members_from_the_reference_summing_to_one(
    basket: Basket,
) -> None:
    """A basket that resolves to nothing would draft an order of nothing."""
    weights = basket_weights(basket)
    known = {asset.symbol for asset in MARKET_REFERENCE}

    assert weights
    assert {symbol for symbol, _ in weights} <= known
    assert sum((weight for _, weight in weights), ZERO) == Decimal(1)


def test_an_ecosystem_splits_equally_across_everything_settling_on_it() -> None:
    """Ethereum carries four of the eight, across three asset classes (OD-2)."""
    weights = dict(basket_weights("ethereum"))

    assert set(weights) == {"ETH", "LINK", "AAVE", "ARB"}
    assert set(weights.values()) == {Decimal("0.25")}


def test_units_are_floored_to_the_step_and_a_zero_leg_is_kept() -> None:
    """ "About" is a ceiling; a zero leg keeps the theme's member on the ticket.

    Flooring to a *whole unit* was the equity rule, and $10,000 spread over
    BTC would have floored to zero under it (spec 0044 OD-6).
    """
    legs = basket_legs("majors", Decimal(500))

    assert format_legs(legs) == "BTC:0.00,ETH:0.0,SOL:0"
    assert format_legs(basket_legs("majors", Decimal(2000))) == "BTC:0.01,ETH:0.2,SOL:3"
