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
- *"Compare keeping BTC against trimming it by a third"* drew a tax-lot
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

from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED
from tests.unit.agent.catalog_reach_data import CLIENT_ONLY, DECLARED_GAPS

#: Views the agent must NOT be expected to compose, each with the reason.
#:
#: A view earns a line here by being something a *screen* asks for, not
#: something an *answer* is. Anything else is a gap, and gaps go in the table
#: below where they have an owner.


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
    """The six the scripted flows and the live battery actually produce.

    Named literally rather than counted: a count goes green when a view is
    added and another is lost, which is the failure mode of every "N of M"
    assertion in this repository's history.
    """
    assert _reachable() == {
        "attribution.driver.v1",
        # Was `attribution.waterfall.v1` until spec `backend/0039`. The swap
        # is the fix, not a loss of reach: `compute_attribution` computes a
        # window and now attaches the surface that draws one.
        "attribution.window.v1",
        "holdings.allocation.v1",
        "order.ticket.v2",
        # Closed by GGU-143. It was a DECLARED_GAP for four specs' worth of
        # work — registered, served, bound and measured, with no turn that
        # drew it — and `compare_lot_methods` is what moved it across.
        "scenario.comparison.v1",
        "taxlots.table.v1",
    }
