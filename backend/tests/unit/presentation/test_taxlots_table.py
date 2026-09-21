"""AC-2/5/6/7/8/9 — ``taxlots.table.v1`` rendered over the seeded portfolio.

Every number asserted here is a literal: the render is pure and the portfolio
is seeded at a frozen ``as_of``, so a changed string means the payload a widget
binds changed, which is a contract change.

The seeded BTC position is the point — 0.42 units at 367 days (long) and 0.18
at 363 days (short) — so the default 0.5-unit sale crosses the boundary and the
short/long split has both halves to show.
"""

import pytest
from pydantic import ValidationError

from app.core.errors import ValidationFailedError
from app.domain.errors import (
    PositionTooSmallError,
    SaleQuantityError,
    SymbolNotFoundError,
)
from app.domain.portfolio import Portfolio
from app.domain.terms import LotTerm
from app.presentation.views.taxlots_table import (
    VIEW_ID,
    TaxLotsTableOptions,
    fitness,
    render,
)


def test_render_walks_the_lots_the_sale_consumes(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions())
    assert payload.view == VIEW_ID
    assert payload.subtitle == "Sell 0.5 BTC under FIFO"
    assert payload.proceeds.amount.display == "$32,125.00"
    assert payload.cost_basis.amount.display == "$22,620.00"
    assert payload.realized.amount.display == "+$9,505.00"
    assert [(row.label, row.term, row.fully_sold) for row in payload.lots] == [
        ("lot-btc-01", LotTerm.LONG, True),
        ("lot-btc-02", LotTerm.SHORT, False),
    ]


def test_render_is_pure_over_the_same_portfolio(portfolio: Portfolio) -> None:
    assert render(portfolio, TaxLotsTableOptions()) == render(
        portfolio, TaxLotsTableOptions()
    )


@pytest.mark.parametrize(
    ("method", "first_lot", "realized"),
    [
        ("FIFO", "lot-btc-01", "+$9,505.00"),
        ("LIFO", "lot-btc-02", "+$8,105.00"),
        ("HIFO", "lot-btc-02", "+$8,105.00"),
    ],
    ids=["FIFO", "LIFO", "HIFO"],
)
def test_render_honours_the_lot_method(
    portfolio: Portfolio, method: str, first_lot: str, realized: str
) -> None:
    """Which lots go first changes the table and the tax result with it."""
    payload = render(portfolio, TaxLotsTableOptions(lot_method=method))  # pyright: ignore[reportArgumentType]
    assert payload.lots[0].label == first_lot
    assert payload.realized.amount.display == realized
    assert payload.subtitle.endswith(method)


@pytest.mark.parametrize(
    ("sections", "has_lots"),
    [(["lots"], True), ([], False)],
    ids=["lots-selected", "nothing-selected"],
)
def test_render_trims_unselected_sections(
    portfolio: Portfolio, sections: list[str], has_lots: bool
) -> None:
    """`fields` trims the table — never the split or the totals (AC-6)."""
    payload = render(portfolio, TaxLotsTableOptions(fields=tuple(sections)))
    assert bool(payload.lots) is has_lots
    assert len(payload.by_term) == len(LotTerm)
    assert payload.realized.amount.display == "+$9,505.00"


@pytest.mark.parametrize(
    "section",
    ["by_term", "remaining"],
    ids=["never-offered", "withdrawn-by-0024"],
)
def test_render_rejects_an_unknown_section(portfolio: Portfolio, section: str) -> None:
    """`remaining` is now as unknown as a section that never existed (§7)."""
    with pytest.raises(ValidationFailedError, match=section):
        render(portfolio, TaxLotsTableOptions(fields=(section,)))


@pytest.mark.parametrize(
    "bad",
    [{"top_n": 3}, {"precision": 9}, {"symbol": "B$"}, {"quantity": "half"}],
    ids=["undeclared", "precision", "symbol", "quantity"],
)
def test_options_reject_what_they_do_not_declare(bad: dict[str, object]) -> None:
    """An undeclared or out-of-range option is a rejection, not a guess."""
    with pytest.raises(ValidationError):
        TaxLotsTableOptions(**bad)  # pyright: ignore[reportArgumentType]


@pytest.mark.parametrize(
    ("scenario", "expected", "message"),
    [
        ({"symbol": "ZZZ"}, SymbolNotFoundError, "ZZZ"),
        ({"quantity": "99"}, PositionTooSmallError, "BTC"),
        ({"quantity": "0"}, SaleQuantityError, "positive"),
    ],
    ids=["unknown-symbol", "over-sell", "zero-quantity"],
)
def test_a_scenario_the_data_cannot_satisfy_raises(
    portfolio: Portfolio,
    scenario: dict[str, str],
    expected: type[Exception],
    message: str,
) -> None:
    """A scenario the data refuses fails loudly, not as a plausible table."""
    with pytest.raises(expected, match=message):
        render(portfolio, TaxLotsTableOptions(**scenario))  # pyright: ignore[reportArgumentType]


def test_a_lowercase_ticker_is_normalised_by_the_domain(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions(symbol="btc"))
    assert payload.subtitle == "Sell 0.5 BTC under FIFO"


def test_fitness_never_selects_this_view(
    portfolio: Portfolio, empty_portfolio: Portfolio
) -> None:
    """A sale scenario cannot be inferred from a portfolio (AC-9)."""
    assert fitness(portfolio) == 0
    assert fitness(empty_portfolio) == 0
