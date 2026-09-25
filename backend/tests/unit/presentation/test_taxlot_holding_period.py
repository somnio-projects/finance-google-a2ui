"""How long each lot was held (spec 0049 AC-1, AC-2).

Its own file rather than two more cases in ``test_taxlots_table``: the second
test is not another literal, it is the **relationship** between two fields of
one cell, which is the kind of claim that file's docstring explicitly does not
make ("every number asserted here is a literal").
"""

from app.domain.portfolio import Portfolio
from app.domain.terms import LotTerm
from app.presentation.views.taxlots_table import TaxLotsTableOptions, render


def test_every_row_states_how_long_the_lot_was_held(portfolio: Portfolio) -> None:
    """AC-1/AC-2 — the duration the client may not compute (spec 0049 OD-2)."""
    payload = render(portfolio, TaxLotsTableOptions())
    # The seeded BTC lots sit one on each side of the boundary — 367 days and
    # 363 — so one render exercises both forms of the string.
    assert [row.holding_period_display for row in payload.lots] == [
        "1.0 yr",
        "12 mo",
    ]


def test_the_duration_and_the_term_pill_cannot_disagree(portfolio: Portfolio) -> None:
    """AC-2 — asserted as the **relationship**, not as two more literals.

    The two halves of that cell are read as one statement, so a table whose
    pill says *Long-term* beside `142 d` is wrong even though both figures are
    individually right (`.claude/rules/backend/testing.md`). Both are derived
    from the same comparison, and this is what holds them to it — over every
    row of every quantity the seeded position can satisfy, so a fourth lot
    added to the seed is covered the day it lands.
    """
    for quantity in ("0.25", "0.75", "1.5", "2.1"):
        payload = render(portfolio, TaxLotsTableOptions(quantity=quantity))
        assert payload.lots, "a sale with no rows would prove nothing"
        for row in payload.lots:
            years = row.holding_period_display.endswith(" yr")
            assert years is (row.term is LotTerm.LONG), (
                f"{row.label}: {row.term} beside {row.holding_period_display!r}"
            )
