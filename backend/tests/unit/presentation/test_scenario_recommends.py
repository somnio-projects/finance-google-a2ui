"""Spec 0051 — what the comparison is now allowed to claim, and no more.

Its own file because the suite it came from is at the budget, and because the
question is different in kind from the ones there: those check that the
figures are right, this checks that the **claim about them** is one the card
can defend.
"""

from decimal import Decimal

import pytest

from app.domain.lot_selection import LotMethod
from app.domain.portfolio import Portfolio
from app.presentation.scenario_options import ScenarioComparisonOptions
from app.presentation.views.scenario_comparison import (
    ScenarioComparisonPayload,
    render,
)


@pytest.fixture(name="card")
def _card(portfolio: Portfolio) -> ScenarioComparisonPayload:
    """The default comparison, rendered once for this file."""
    return render(portfolio, ScenarioComparisonOptions())


def test_the_card_recommends_exactly_what_it_can_defend(
    card: ScenarioComparisonPayload,
) -> None:
    """Spec 0051 — this test used to assert the opposite, and that is the point.

    It read *"the card ranks nothing and recommends nothing"* and asserted
    that no field named `recommended`, `best`, `rank`, `score` or `winner`
    existed anywhere on the payload — spec 0017 OD-4, which was right while
    the card had no tax rate to rank by. GGU-134 gave it one, declared and
    printed, so the ruling is superseded rather than broken.

    What replaces it is not "anything goes". A ranking is allowed **only**
    when it is the server's, singular, and reversible by the reader:

    1. `recommended` agrees with the `net_after_tax` row's winner — one claim,
       one source;
    2. at most one column carries it;
    3. the rates it ranks by are on the card;
    4. the *Not advice* note is still there.
    """
    net = next(row for row in card.rows if row.key == "net_after_tax")
    tagged = [column.key for column in card.columns if column.recommended]

    assert tagged == ([net.winner] if net.winner else [])
    assert len(tagged) <= 1
    assert any("estimated at" in note.text for note in card.notes)
    assert any(note.label == "Not advice" for note in card.notes)


def test_columns_keep_the_requested_order_and_are_never_sorted_by_outcome(
    portfolio: Portfolio,
) -> None:
    asked = (LotMethod.HIFO, LotMethod.FIFO)
    card = render(portfolio, ScenarioComparisonOptions(methods=asked))
    assert tuple(column.method for column in card.columns) == asked


def test_a_sale_that_closes_the_position_reports_no_difference(
    portfolio: Portfolio,
) -> None:
    card = render(portfolio, ScenarioComparisonOptions(quantity=Decimal("2.10")))
    assert card.spread.differs is False
    assert card.spread.amount.display == "$0.00"
    assert card.spread.highest is None
    assert card.spread.lowest is None
    assert card.notes[-1].label == "No difference"


def test_the_unit_price_is_quoted_at_price_precision(portfolio: Portfolio) -> None:
    card = render(portfolio, ScenarioComparisonOptions(symbol="link"))
    assert card.subject.symbol == "LINK"
    assert card.subject.price.display == "$22.60"
    assert card.subject.proceeds.display == "$47,460.00"
