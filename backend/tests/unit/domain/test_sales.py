"""Spec 0013 — what a simulated sale realises.

What it refuses, and what it leaves behind, is `test_sales_limits.py`. Every
assertion here is against the domain's own ``Decimal`` values: parsing a
display string back into a number would test the formatter and call it
arithmetic.
"""

from decimal import Decimal

import pytest

from app.domain.lot_selection import LotMethod
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.sales import simulate_sale
from app.domain.terms import LotTerm
from tests.unit.domain.conftest import make_lot, make_portfolio

BTC_PRICE = Decimal("64250.00")

#: Age order and price order disagree, so each method realises a different
#: gain on the very same unit sold. The seed cannot prove this: there BTC's
#: newest lot is also its dearest, and LIFO and HIFO answer alike (AC-3).
DISAGREEING = make_portfolio(
    make_lot(lot_id="lot-old", days_before=400, cost_basis="30000.00"),
    make_lot(lot_id="lot-dear", days_before=200, cost_basis="50000.00"),
    make_lot(lot_id="lot-new", days_before=100, cost_basis="40000.00"),
)


@pytest.mark.parametrize(
    ("method", "lot_id", "realized"),
    [
        (LotMethod.FIFO, "lot-old", "34250.00"),
        (LotMethod.LIFO, "lot-new", "24250.00"),
        (LotMethod.HIFO, "lot-dear", "14250.00"),
    ],
    ids=["fifo_realises_the_most", "lifo_the_middle", "hifo_the_least"],
)
def test_each_method_consumes_the_lot_it_names(
    method: LotMethod, lot_id: str, realized: str
) -> None:
    """AC-3 — the same unit sold three ways gives three tax bills."""
    result = simulate_sale(
        DISAGREEING, symbol="BTC", quantity=Decimal(1), method=method
    )

    assert [row.lot_id for row in result.consumed] == [lot_id]
    assert result.realized_pl == Decimal(realized)
    assert result.proceeds == BTC_PRICE


def test_the_consumed_lots_sum_to_the_totals(portfolio: Portfolio) -> None:
    """AC-2 — the comparator's rows reach its own totals, exactly."""
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.5"))

    assert len(result.consumed) == 2
    assert sum((row.proceeds for row in result.consumed), ZERO) == result.proceeds
    assert sum((row.cost_basis for row in result.consumed), ZERO) == result.cost_basis
    assert result.realized_pl == result.proceeds - result.cost_basis
    assert result.closes()


def test_the_term_split_sums_to_the_realised_result(portfolio: Portfolio) -> None:
    """AC-2 — short plus long is the whole answer, with nothing in between."""
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.5"))

    short = result.pl_in(LotTerm.SHORT)
    long_term = result.pl_in(LotTerm.LONG)
    assert short + long_term == result.realized_pl
    assert result.lots_in(LotTerm.SHORT) + result.lots_in(LotTerm.LONG) == 2


def test_a_sale_spanning_the_boundary_splits_short_from_long(
    portfolio: Portfolio,
) -> None:
    """AC-4 — the seeded BTC lots sit at 367 and 363 days, either side of it.

    The classification is ``app.domain.terms``' (OD-7); what is asserted here
    is that a *sale* carries it through to the row the reader sees, and that
    each lot's gain lands in the half it belongs to.
    """
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.5"))

    by_id = {row.lot_id: row for row in result.consumed}
    assert by_id["lot-btc-01"].term is LotTerm.LONG
    assert by_id["lot-btc-02"].term is LotTerm.SHORT
    assert result.pl_in(LotTerm.LONG) == by_id["lot-btc-01"].gain_loss
    assert result.pl_in(LotTerm.SHORT) == by_id["lot-btc-02"].gain_loss


def test_a_partly_consumed_lot_gives_up_its_basis_pro_rata(
    portfolio: Portfolio,
) -> None:
    """Nine hundredths of a lot costs nine hundredths of what the lot cost."""
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.51"))

    partial = result.consumed[1]
    whole = next(
        lot for lot in portfolio.tax_lots("BTC") if lot.lot_id == partial.lot_id
    )
    assert not partial.exhausted
    assert partial.quantity == Decimal("0.09")
    assert partial.cost_basis == whole.cost_basis * partial.quantity / whole.quantity


def test_a_ticker_is_normalised_before_anything_else(portfolio: Portfolio) -> None:
    """Spec 0003 AC-4 — the caller may write the ticker however they like."""
    result = simulate_sale(portfolio, symbol="  btc  ", quantity=Decimal("0.1"))

    assert result.symbol == "BTC"
