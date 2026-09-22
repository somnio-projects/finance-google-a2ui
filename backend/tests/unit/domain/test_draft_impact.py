"""Spec 0031 — what a draft costs, buys and leaves, stated by the domain.

The figures are literals over the seeded portfolio (spec 0025): the design's
own three legs at the seeded prices. A derivation that recomputed them from
the code under test could not fail.
"""

from decimal import Decimal

from app.domain.draft_impact import cash_available, draft_impact, price_legs
from app.domain.draft_legs import LegRequest, parse_legs
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio

DESIGN_LEGS = parse_legs("NVDA:3,AVGO:2,AMD:14")


def test_the_portfolio_holds_the_design_cash(portfolio: Portfolio) -> None:
    """The bound a buy is checked against is the seeded `USD · Cash & sweep`."""
    assert cash_available(portfolio) == Decimal("38633.22")


def test_price_legs_strikes_each_at_its_reference_price() -> None:
    """AC-2 — quantity times price, and the weights close to one."""
    legs = price_legs(DESIGN_LEGS)

    assert [(leg.symbol, leg.notional) for leg in legs] == [
        ("NVDA", Decimal("3613.98")),
        ("AVGO", Decimal("3480.00")),
        ("AMD", Decimal("2333.80")),
    ]
    assert legs[0].name == "NVIDIA Corp"
    assert sum((leg.weight for leg in legs), ZERO) == Decimal(1)


def test_an_order_for_nothing_weighs_every_leg_at_zero() -> None:
    """Zero shares everywhere is representable, not a division by nothing."""
    legs = price_legs((LegRequest(symbol="NVDA", quantity=0),))

    assert legs[0].notional == ZERO
    assert legs[0].weight == ZERO


def test_a_buy_within_cash_spends_it_and_is_not_short(portfolio: Portfolio) -> None:
    """AC-5 — total, shares and cash remaining, from one statement."""
    impact = draft_impact(portfolio, DESIGN_LEGS, "buy")

    assert impact.total == Decimal("9427.78")
    assert impact.units == Decimal(19)
    assert impact.fees == ZERO
    assert impact.cash_available == Decimal("38633.22")
    assert impact.cash_after == Decimal("29205.44")
    assert impact.shortfall == ZERO


def test_a_buy_beyond_cash_names_the_shortfall(portfolio: Portfolio) -> None:
    """AC-6 — the blocked state is a figure, not a comparison the client makes."""
    impact = draft_impact(portfolio, parse_legs("NVDA:40,AVGO:2,AMD:14"), "buy")

    assert impact.total == Decimal("54000.20")
    assert impact.cash_after == Decimal("-15366.98")
    assert impact.shortfall == Decimal("15366.98")


def test_a_sell_raises_cash_and_is_never_short(portfolio: Portfolio) -> None:
    """OD-7 — sufficiency of a sale is `simulate_sale`'s question, not this one."""
    impact = draft_impact(portfolio, parse_legs("NVDA:40,AVGO:2,AMD:14"), "sell")

    assert impact.cash_after == Decimal("92633.42")
    assert impact.shortfall == ZERO
