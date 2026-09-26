"""Spec 0050 — the stops a leg's slider can land on.

The slider sets the **mix**: a stop is the draft rebalanced so one leg carries
a different share while the order's total stays where it is. The properties
are asserted as **relationships** — a ladder transcribed as a literal would
still pass if the rule that built it were wrong, and the rule is the thing
under test.
"""

from decimal import Decimal

import pytest

from app.domain.draft_ladder import MAX_LADDER, MAX_STOPS, ladder
from app.domain.draft_legs import LegRequest, parse_legs
from app.domain.market import market_asset
from app.domain.money import ZERO

DESIGN_LEGS = parse_legs("BTC:0.06,ETH:1.0,SOL:16")
LEGS = ("BTC", "ETH", "SOL")


def _notional(legs: tuple[LegRequest, ...], symbol: str) -> Decimal:
    """What one leg is worth at the reference price."""
    leg = next(item for item in legs if item.symbol == symbol)
    return leg.quantity * market_asset(symbol).price


def _total(legs: tuple[LegRequest, ...]) -> Decimal:
    """What the whole draft is worth."""
    return sum((_notional(legs, leg.symbol) for leg in legs), ZERO)


def _weight(legs: tuple[LegRequest, ...], symbol: str) -> Decimal:
    """One leg's share of the draft."""
    return _notional(legs, symbol) / _total(legs)


@pytest.mark.parametrize("symbol", LEGS)
def test_the_value_on_screen_is_always_a_stop(symbol: str) -> None:
    """AC-1 — the ladder is aligned to the current weight, so it contains it."""
    rung = ladder(DESIGN_LEGS, symbol)

    assert rung.stops[int(rung.position)] == "BTC:0.06,ETH:1.0,SOL:16"


@pytest.mark.parametrize("symbol", LEGS)
def test_the_thumb_sits_where_the_weight_is(symbol: str) -> None:
    """AC-1 — the whole reason the ladder walks weight and not units.

    The position along the track and the percentage printed beside it are the
    same quantity, to within one stride. Under the units ladder this gap was
    ~29 points on every leg, which is the measurement that changed OD-1.
    """
    rung = ladder(DESIGN_LEGS, symbol)
    fraction = Decimal(int(rung.position)) / (len(rung.stops) - 1)

    assert abs(fraction - _weight(DESIGN_LEGS, symbol)) < Decimal("0.05")


@pytest.mark.parametrize("symbol", LEGS)
def test_a_stop_moves_the_mix_and_leaves_the_size(symbol: str) -> None:
    """AC-1 — the total is what a drag holds constant; the split is what moves."""
    rung = ladder(DESIGN_LEGS, symbol)
    before = _total(DESIGN_LEGS)

    for stop in rung.stops:
        after = parse_legs(stop)
        # Written to eight decimals, so the total is preserved to about a cent
        # on a $9,773 draft rather than exactly.
        assert abs(_total(after) - before) < Decimal("0.01")


@pytest.mark.parametrize("symbol", LEGS)
def test_the_stops_ascend_by_this_leg_s_weight(symbol: str) -> None:
    """AC-1 — a ladder a thumb can walk: monotone, and with no repeats."""
    rung = ladder(DESIGN_LEGS, symbol)
    weights = [_weight(parse_legs(stop), symbol) for stop in rung.stops]

    assert weights == sorted(weights)
    assert len(weights) == len(set(weights))


@pytest.mark.parametrize("symbol", LEGS)
def test_both_ends_are_reachable(symbol: str) -> None:
    """AC-1 — a leg can be taken to nothing, or given the whole order."""
    rung = ladder(DESIGN_LEGS, symbol)
    first = parse_legs(rung.stops[0])
    last = parse_legs(rung.stops[-1])

    assert _notional(first, symbol) == ZERO
    assert _weight(last, symbol) == Decimal(1)


@pytest.mark.parametrize("symbol", LEGS)
def test_the_others_keep_their_proportions(symbol: str) -> None:
    """AC-1 — the rest of the basket absorbs the move without being reordered."""
    rung = ladder(DESIGN_LEGS, symbol)
    others = [leg for leg in LEGS if leg != symbol]
    before = _notional(DESIGN_LEGS, others[0]) / _notional(DESIGN_LEGS, others[1])

    middle = parse_legs(rung.stops[len(rung.stops) // 2])
    after = _notional(middle, others[0]) / _notional(middle, others[1])

    assert abs(after - before) < Decimal("0.0001")


@pytest.mark.parametrize("symbol", LEGS)
def test_the_ladder_stays_inside_the_published_bound(symbol: str) -> None:
    """AC-1 — the payload declares `MAX_LADDER`; the writer may not exceed it."""
    assert len(ladder(DESIGN_LEGS, symbol).stops) <= MAX_LADDER


@pytest.mark.parametrize("symbol", LEGS)
def test_the_ladder_is_as_fine_as_it_claims(symbol: str) -> None:
    """AC-1 — a stride of five points, so the track is not four stops long."""
    assert len(ladder(DESIGN_LEGS, symbol).stops) >= MAX_STOPS


def test_a_draft_worth_nothing_has_no_mix_to_move() -> None:
    """AC-1 — zero everywhere: one stop, and a track that cannot be dragged."""
    legs = parse_legs("BTC:0,ETH:0")
    rung = ladder(legs, "BTC")

    assert rung.stops == ("BTC:0,ETH:0",)
    assert rung.position == "0"


def test_a_leg_that_is_already_the_whole_order_has_no_mix_to_move() -> None:
    """AC-1 — nothing to redistribute to, so the ladder is where it stands."""
    legs = parse_legs("BTC:0.06,ETH:0")
    rung = ladder(legs, "BTC")

    assert rung.stops == ("BTC:0.06,ETH:0",)
    assert rung.position == "0"


def test_a_single_leg_draft_has_no_mix_to_move() -> None:
    """AC-1 — one leg is always the whole order, whatever the slider does."""
    rung = ladder(parse_legs("BTC:0.06"), "BTC")

    assert rung.stops == ("BTC:0.06",)
