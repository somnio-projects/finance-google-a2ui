"""What a sell row says it realised, and in which term (spec 0035 AC-5).

Split from `test_activity_timeline.py` under the 150-line budget, along the
seam already there: that module is about the timeline's *shape* — sections,
filters, limits — and this is about the one row kind that has to walk the
ledger before it can say anything.
"""

from app.domain.portfolio import Portfolio
from app.presentation.activity_rows import ActivityOptions
from app.presentation.views.activity_timeline import render


def test_every_sell_carries_its_realised_result_and_the_term_badge(
    portfolio: Portfolio,
) -> None:
    """Seven sales, and between them all four badges (spec 0035 AC-5).

    The badge used to read `ST gain` whatever the sign, which nothing caught
    while the seed held one sale and it was a gain (spec 0035 OD-5). The
    literals below are the assertion that it no longer does.
    """
    payload = render(portfolio, ActivityOptions(kind="sell"))
    sales = {entry.key: entry for group in payload.groups for entry in group.entries}
    assert len(sales) == 7
    voo = sales["txn-0015"]
    assert (voo.title, voo.detail) == ("Sold 20 VOO", "20 sh @ $489.00 · Feb 20")
    assert voo.amount.display == "$9,780.00"
    assert voo.realized is not None and voo.term is not None
    assert (voo.realized.text, voo.realized.trend) == ("+$1,738 realized", "up")
    badges = {
        key: (entry.term.label, entry.realized.text)
        for key, entry in sales.items()
        if entry.term is not None and entry.realized is not None
    }
    assert badges == {
        "txn-0015": ("ST gain", "+$1,738 realized"),
        "txn-0024": ("ST loss", "-$105 realized"),
        "txn-0025": ("LT gain", "+$2,745 realized"),
        "txn-0026": ("ST loss", "-$870 realized"),
        "txn-0027": ("LT loss", "-$175 realized"),
        "txn-0028": ("ST gain", "+$2,550 realized"),
        "txn-0029": ("LT gain", "+$880 realized"),
    }
