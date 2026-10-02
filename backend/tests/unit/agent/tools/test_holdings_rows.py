"""Spec 0011 OD-2 — the position the seeded portfolio does not contain.

``cost_basis`` is ``ge=0``, so a zero-cost position is representable and the
row shaping has a branch for it. The seed has no airdrop, so the branch is
reached here, with a hand-built ``Holding``, rather than left untested.
"""

from decimal import Decimal

from app.agent.tools import holdings_rows
from tests.unit.agent.tools.holdings_fixtures import AIRDROP


def test_a_position_with_no_cost_basis_reports_no_percentage_return() -> None:
    row = holdings_rows.row(AIRDROP)

    assert row["unrealizedPlPctDisplay"] is None
    assert row["unrealizedPlDisplay"] == "+$500.00"
    assert row["trend"] == "up"
    assert row["costBasisDisplay"] == "$0.00"


def test_totals_over_a_zero_cost_portfolio_report_no_percentage_return() -> None:
    block = holdings_rows.totals(
        count=1,
        market_value=Decimal("500"),
        cost_basis=Decimal(0),
        unrealized_pl=Decimal("500"),
    )

    assert block["unrealizedPlPctDisplay"] is None
    assert block["costBasisDisplay"] == "$0.00"
    assert block["count"] == 1


def test_a_sub_cent_price_multiplies_back_to_the_market_value_beside_it() -> None:
    """Spec 0013 S1 — the row must not contradict itself.

    LINK is quoted at ``0.1273``. Rounded to cents the row reads ``$0.13``,
    and 12,000 times $0.13 is $1,560.00, which is $32.40 away from the market value in
    the same row. The tool that found this (`simulate_sale`) fixed its own
    block; this is the same bug in the holdings row, fixed with the same
    helper rather than a second one.
    """
    doge = AIRDROP.model_copy(
        update={
            "symbol": "LINK",
            "name": "Exxon Mobil",
            "quantity": Decimal("130"),
            "price": Decimal("34.22"),
            "market_value": Decimal("4448.60"),
            "cost_basis": Decimal("5460.00"),
            "unrealized_pl": Decimal("-1011.40"),
        }
    )

    row = holdings_rows.row(doge)

    assert row["priceDisplay"] == "$34.22"
    assert row["marketValueDisplay"] == "$4,448.60"
    assert doge.quantity * doge.price == doge.market_value


def test_a_cent_exact_price_keeps_the_two_decimals_a_reader_expects() -> None:
    """The helper widens only when it has to — BTC stays ``$1,204.66``."""
    btc = AIRDROP.model_copy(
        update={"symbol": "BTC", "price": Decimal("1204.66"), "quantity": Decimal("1")}
    )

    assert holdings_rows.row(btc)["priceDisplay"] == "$1,204.66"
