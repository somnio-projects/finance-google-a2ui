"""Every registered view is either reachable by the agent, or a declared gap.

**The defect this file exists for.** A projection can be written, registered,
100 %-covered, published to `/v1/views`, printed in the frozen contract and
bound by a Flutter component — and remain **impossible for the agent to
compose**, because a render intent is attached by a *tool* and no tool names
it. Nothing in the gate noticed. Measured on 2026-09-22: 11 views registered,
**5** reachable.

Two of the day's symptoms were that, and neither looked like it:

- *"Show me my biggest winners and losers"* answered in prose, because
  `holdings.positions.v1` is unreachable;
- *"Compare keeping NVDA against trimming it by a third"* drew a tax-lot
  table, because `scenario.comparison.v1` is unreachable and the model
  reached for the nearest thing it could actually get.

This is GGU-79's finding one level up. There, a component could be registered
and still not reachable from a *route*, and the fix was to compare the router
with the registry. Here it is the *agent* that cannot reach it, and the fix is
the same shape: compare the tool surface with the registry, and require every
absence to be a sentence somebody wrote.

**What this test is not.** It does not say every view must be agent-reachable
— a view the client requests by `?view=` on a tab is legitimately not the
agent's to compose. It says the decision must be **declared**. A new view is
red here until its author classifies it, exactly as `test_component_names.py`
is red until design has named it.
"""

import re
from pathlib import Path
from typing import Final

from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED

#: Views the agent must NOT be expected to compose, each with the reason.
#:
#: A view earns a line here by being something a *screen* asks for, not
#: something an *answer* is. Anything else is a gap, and gaps go in the table
#: below where they have an owner.
CLIENT_ONLY: Final[dict[str, str]] = {
    "portfolio.summary.v1": (
        "The Home hero. The shell requests it by `?view=` on load; an agent "
        "turn that re-drew the header the user is already looking at would be "
        "noise, not an answer."
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
        "Activity tab now shows sixteen of them — spec backend/0035 "
        "quadrupled the seeded dividends, which makes the gap MORE visible "
        "rather than closing it. Recorded there as OD-11: a dividend-income "
        "tool needs its own *Display figures, its own prompt fragment and a "
        "period rule the domain does not have, so it is a spec of its own."
    ),
    "holdings.positions.v1": (
        "`get_holdings_summary` sorts by `gainers`/`losers` but attaches no "
        "surface for them — `holdings.allocation.v1` is suppressed for a "
        "return-ordered answer (spec 0011 OD-1) and nothing takes its place. "
        "Spec backend/0035 gave this view `query` and `asset_class` options, "
        "which the TABS send; it attached no tool, so the agent still cannot "
        "compose it and the gap stands. Unowned from here."
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


def _registered() -> set[str]:
    """Every view id the projection registry knows about."""
    assert LOADED
    return {projection.id for projection in REGISTRY.all()}


def _reachable() -> set[str]:
    """Every view id a tool module can attach to a render intent.

    Read out of the tool sources rather than by running them: a tool attaches
    its view through a module-level ``VIEW`` constant, and exercising every
    tool against a portfolio to discover which intents appear would make this
    inventory depend on the seed data rather than on the code.
    """
    pattern = re.compile(r'VIEW[A-Z_]*:\s*Final\[str\]\s*=\s*"([^"]+)"')
    tools = Path(__file__).parents[3] / "src" / "app" / "agent" / "tools"
    return {
        match.group(1)
        for module in tools.glob("*.py")
        for match in pattern.finditer(module.read_text())
    }


def test_every_registered_view_is_classified() -> None:
    """A new view is red here until somebody says which of the three it is."""
    classified = _reachable() | set(CLIENT_ONLY) | set(DECLARED_GAPS)
    unclassified = _registered() - classified

    assert not unclassified, (
        f"{sorted(unclassified)} are registered and the agent cannot compose "
        "them. Either attach them from a tool, or add a line to CLIENT_ONLY "
        "or DECLARED_GAPS in this file saying why not. An undeclared gap is "
        "a component nobody knows is unreachable."
    )


def test_no_classification_names_a_view_that_does_not_exist() -> None:
    """The reverse direction: a stale line is a lie that reads as a decision."""
    registered = _registered()

    assert set(CLIENT_ONLY) <= registered
    assert set(DECLARED_GAPS) <= registered


def test_a_declared_gap_is_not_also_reachable() -> None:
    """Closing a gap means deleting its line, not leaving both true."""
    reachable = _reachable()

    assert not (reachable & set(DECLARED_GAPS))
    assert not (reachable & set(CLIENT_ONLY))


def test_the_agent_reaches_the_views_the_demo_depends_on() -> None:
    """The five the scripted flows and the live battery actually produce.

    Named literally rather than counted: a count goes green when a view is
    added and another is lost, which is the failure mode of every "N of M"
    assertion in this repository's history.
    """
    assert _reachable() == {
        "attribution.driver.v1",
        "attribution.waterfall.v1",
        "holdings.allocation.v1",
        "order.ticket.v2",
        "taxlots.table.v1",
    }
