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
    btc = sales["txn-0015"]
    assert (btc.title, btc.detail) == (
        "Sold 0.25 BTC",
        "0.25 units @ $58,400.00 · Jul 20",
    )
    assert btc.amount.display == "$14,600.00"
    assert btc.realized is not None and btc.term is not None
    assert (btc.realized.text, btc.realized.trend) == ("+$5,600 realized", "up")
    badges = {
        key: (entry.term.label, entry.realized.text)
        for key, entry in sales.items()
        if entry.term is not None and entry.realized is not None
    }
    assert badges == {
        "txn-0010": ("ST gain", "+$2,560 realized"),
        "txn-0011": ("LT gain", "+$3,250 realized"),
        "txn-0012": ("LT loss", "-$735 realized"),
        "txn-0013": ("LT loss", "-$1,962 realized"),
        "txn-0014": ("ST loss", "-$2,420 realized"),
        "txn-0015": ("ST gain", "+$5,600 realized"),
        "txn-0016": ("ST gain", "+$19,800 realized"),
    }
