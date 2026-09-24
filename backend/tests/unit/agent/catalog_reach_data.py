"""Which registered views the agent cannot compose, and why — the data half.

Split out of ``test_catalog_reach.py`` when that file passed the 150-line
budget. The seam is the one ``tests/catalog.py`` already draws: an inventory
is data, the assertions over it are a test. Each entry is a **promise or a
ruling**, not a shrug, so they are written at length here rather than
compressed to fit beside the code that reads them.
"""

from typing import Final

CLIENT_ONLY: Final[dict[str, str]] = {
    "portfolio.summary.v1": (
        "The Home hero. The shell requests it by `?view=` on load; an agent "
        "turn that re-drew the header the user is already looking at would be "
        "noise, not an answer."
    ),
    "attribution.waterfall.v1": (
        "The all-time walk. It WAS reachable through `compute_attribution`, "
        "and that was the defect spec `backend/0039` closes: that tool "
        "computes a **window**, so it attached a surface drawing a different "
        "quantity and the chart contradicted the sentence above it. It now "
        "attaches `attribution.window.v1`. This projection stays the right "
        "answer to *how much am I up on each holding?* — a screen asked for "
        "by id, not a turn."
    ),
    "order.ticket.v1": (
        "Superseded by `order.ticket.v2` (spec 0031), which IS reachable. The "
        "v1 projection stays registered because `/v1` is a contract and a "
        "client may still request it; nothing new should produce it."
    ),
}

#: Views the agent SHOULD be able to compose and cannot yet, each with the
#: spec that owns closing it. A line here is a promise, not a shrug — and it
#: is visible in a test run rather than buried in a backlog.
DECLARED_GAPS: Final[dict[str, str]] = {
    "activity.timeline.v1": (
        "No tool reads the ledger. Asked what was earned in dividends this "
        "year the agent answers that the data is not available, while the "
        "Activity tab now shows sixteen — spec backend/0035 quadrupled them, "
        "widening the gap rather than closing it, and recorded it as OD-11."
    ),
    "holdings.positions.v1": (
        "`get_holdings_summary` sorts by `gainers`/`losers` but attaches no "
        "surface for them — `holdings.allocation.v1` is suppressed for a "
        "return-ordered answer (spec 0011 OD-1) and nothing takes its place. "
        "Spec backend/0035 gave this view `query` and `asset_class`, which "
        "the TABS send; it attached no tool, so the gap stands. Unowned."
    ),
    "scenario.comparison.v1": (
        "`simulate_sale` computes one scenario and attaches the tax-lot "
        "table; comparing keep-against-trim is exactly this component and no "
        "tool asks for it. Unowned — the next agent feature should take it."
    ),
    "payoff.curve.v1": (
        "No tool produces an option payoff. Unowned; the demo script does not "
        "reach it either, so it is the least urgent of the four."
    ),
}

__all__ = ["CLIENT_ONLY", "DECLARED_GAPS"]
