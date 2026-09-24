"""Spec 0031 — a vague intent becomes legs here, never in the model.

The design's own prompt — *put about $10k into semiconductors* — must compose
the three legs the design draws, at the seeded prices, in whole shares. That
composition is what `order.ticket.v2` defaults to, so the two are compared.
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


def test_semiconductors_composes_the_design_legs_in_whole_shares() -> None:
    """AC-7 — 40 / 35 / 25 of $10k at the seeded prices, floored."""
    legs = basket_legs("semiconductors", TEN_THOUSAND)

    assert legs == (
        LegRequest(symbol="NVDA", quantity=3),
        LegRequest(symbol="AVGO", quantity=2),
        LegRequest(symbol="AMD", quantity=14),
    )


def test_the_ticket_defaults_to_what_the_design_prompt_composes() -> None:
    """Two declarations of one fact, compared instead of trusted."""
    assert format_legs(basket_legs("semiconductors", TEN_THOUSAND)) == DEFAULT_LEGS


def test_the_curated_weights_are_the_designs() -> None:
    assert CURATED["semiconductors"] == (
        ("NVDA", Decimal("0.40")),
        ("AVGO", Decimal("0.35")),
        ("AMD", Decimal("0.25")),
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


def test_a_sector_splits_equally_across_its_single_names_only() -> None:
    """VOO is Technology's fund and a basket already; it is left out."""
    weights = dict(basket_weights("technology"))

    assert set(weights) == {"NVDA", "AAPL", "MSFT", "AVGO", "AMD"}
    assert set(weights.values()) == {Decimal("0.2")}


def test_shares_are_floored_and_a_leg_that_floors_to_zero_is_kept() -> None:
    """ "About" is a ceiling; a zero leg keeps the theme's member on the ticket."""
    legs = basket_legs("semiconductors", Decimal(500))

    assert format_legs(legs) == "NVDA:0,AVGO:0,AMD:0"
    assert format_legs(basket_legs("semiconductors", Decimal(2000))) == (
        "NVDA:0,AVGO:0,AMD:2"
    )
