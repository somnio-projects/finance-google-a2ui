"""Spec 0050 — the stops a leg's slider can land on.

The properties are asserted as **relationships** rather than as a transcribed
list: a ladder that reproduced a literal would still be right if the rule that
built it were wrong, and the rule is the thing under test. The two literals
that do appear are the ones a derivation could not check — the seeded cash and
one hand-walked ladder.
"""

from decimal import Decimal

import pytest

from app.domain.draft_impact import draft_impact
from app.domain.draft_ladder import MAX_LADDER, MAX_STOPS, Ladder, ceiling, ladder
from app.domain.draft_legs import LegRequest, parse_legs
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio

DESIGN_LEGS = parse_legs("BTC:0.06,ETH:1.0,SOL:16")
BEYOND_CASH = parse_legs("BTC:1.0,ETH:1.0,SOL:16")


def _ladder(
    portfolio: Portfolio,
    legs: tuple[LegRequest, ...],
    symbol: str,
    side: Side = "buy",
) -> Ladder:
    """Build one leg's ladder over ``legs``."""
    return ladder(portfolio, draft_impact(portfolio, legs, side), legs, symbol, side)


@pytest.mark.parametrize("symbol", ["BTC", "ETH", "SOL"])
def test_the_value_on_screen_is_always_a_stop(
    portfolio: Portfolio, symbol: str
) -> None:
    """AC-1 — the ladder is aligned to the current value, so it contains it."""
    rung = _ladder(portfolio, DESIGN_LEGS, symbol)

    assert rung.stops[int(rung.position)] == "BTC:0.06,ETH:1.0,SOL:16"


@pytest.mark.parametrize("symbol", ["BTC", "ETH", "SOL"])
def test_both_ends_are_reachable(portfolio: Portfolio, symbol: str) -> None:
    """AC-1 — zero and the ceiling are stops, whatever the stride lands on."""
    rung = _ladder(portfolio, DESIGN_LEGS, symbol)
    quantities = [
        next(leg.quantity for leg in parse_legs(stop) if leg.symbol == symbol)
        for stop in rung.stops
    ]

    assert quantities[0] == ZERO
    assert quantities[-1] == ceiling(
        portfolio, draft_impact(portfolio, DESIGN_LEGS, "buy"), symbol, "buy"
    )


@pytest.mark.parametrize("symbol", ["BTC", "ETH", "SOL"])
def test_the_stops_ascend_and_move_only_this_leg(
    portfolio: Portfolio, symbol: str
) -> None:
    """AC-1 — a stop is the draft with one number moved, never two."""
    rung = _ladder(portfolio, DESIGN_LEGS, symbol)
    seen: list[Decimal] = []
    for stop in rung.stops:
        legs = parse_legs(stop)
        assert [leg.symbol for leg in legs] == ["BTC", "ETH", "SOL"]
        for leg, asked in zip(legs, DESIGN_LEGS, strict=True):
            if leg.symbol != symbol:
                assert leg.quantity == asked.quantity
        seen.append(next(item.quantity for item in legs if item.symbol == symbol))

    assert seen == sorted(seen)
    assert len(seen) == len(set(seen))


@pytest.mark.parametrize("symbol", ["BTC", "ETH", "SOL"])
def test_the_ladder_stays_inside_the_published_bound(
    portfolio: Portfolio, symbol: str
) -> None:
    """AC-1 — the payload declares `MAX_LADDER`; the writer may not exceed it."""
    assert len(_ladder(portfolio, DESIGN_LEGS, symbol).stops) <= MAX_LADDER


def test_a_thin_ladder_uses_every_step(portfolio: Portfolio) -> None:
    """The stride only coarsens when it has to: few steps, every step a stop."""
    legs = parse_legs("BTC:0.02,ETH:1.0,SOL:16")
    impact = draft_impact(portfolio, legs, "buy")
    top = ceiling(portfolio, impact, "BTC", "buy")
    step = market_asset("BTC").step
    if int(top / step) + 1 <= MAX_STOPS:  # pragma: no cover - guards the premise
        rung = ladder(portfolio, impact, legs, "BTC", "buy")
        assert len(rung.stops) == int(top / step) + 1


def test_a_buy_is_bounded_by_what_the_cash_affords(portfolio: Portfolio) -> None:
    """AC-1 — the ceiling is the headroom once the other legs are paid for."""
    impact = draft_impact(portfolio, DESIGN_LEGS, "buy")
    top = ceiling(portfolio, impact, "BTC", "buy")
    headroom = impact.cash_available - (impact.total - impact.legs[0].notional)
    step = market_asset("BTC").step

    assert top * market_asset("BTC").price <= headroom
    assert (top + step) * market_asset("BTC").price > headroom


def test_a_draft_past_its_cash_still_sits_on_its_own_ladder(
    portfolio: Portfolio,
) -> None:
    """AC-1 — the ceiling never falls below the quantity on screen."""
    rung = _ladder(portfolio, BEYOND_CASH, "BTC")

    assert rung.stops[int(rung.position)] == "BTC:1.0,ETH:1.0,SOL:16"
    assert ceiling(
        portfolio, draft_impact(portfolio, BEYOND_CASH, "buy"), "BTC", "buy"
    ) == Decimal("1.0")


def test_a_sell_is_bounded_by_what_is_held(portfolio: Portfolio) -> None:
    """AC-1 — cash is not a sell's bound; the position is."""
    impact = draft_impact(portfolio, DESIGN_LEGS, "sell")
    held = next(row.quantity for row in portfolio.holdings() if row.symbol == "BTC")

    assert ceiling(portfolio, impact, "BTC", "sell") == held


def test_a_sell_of_something_unheld_reaches_only_what_is_asked(
    portfolio: Portfolio,
) -> None:
    """AC-1 — nothing held, so the ladder tops out at the drafted quantity.

    `AVAX` is in the market reference and **not** in the seed, which is what
    makes it the case worth testing: a leg for an asset the portfolio does not
    hold still renders, and its track cannot run past what was asked.
    """
    legs = parse_legs("AVAX:5")
    impact = draft_impact(portfolio, legs, "sell")

    assert all(row.symbol != "AVAX" for row in portfolio.holdings())
    assert ceiling(portfolio, impact, "AVAX", "sell") == Decimal(5)
