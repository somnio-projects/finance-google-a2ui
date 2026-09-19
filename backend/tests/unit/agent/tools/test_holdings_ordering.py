"""Spec 0011 AC-4 — which positions the tool answers with, and in what order.

Every ordering is checked against an oracle written **here**, from the
documented rule, never by calling the production ``SORTERS`` entry the tool
itself calls: that would pass with the comparison inverted. Nothing is
asserted by parsing a number back out of a display string either — that would
prove the formatter and the test agree, not that the answer is right.
"""

from decimal import Decimal

import pytest

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_sort import SORTERS, return_key
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from app.domain.holdings import Holding
from app.domain.returns import return_on_cost
from tests.unit.agent.tools.holdings_fixtures import AIRDROP, held, symbols_of
from tests.unit.agent.tools.holdings_fixtures import tool as tool

FAR_BEHIND = Decimal(-1_000_000)
FAR_AHEAD = Decimal(1_000_000)


def _by_size(positions: list[Holding]) -> list[str]:
    """Rank largest first, ties by symbol — the oracle for weight and value."""
    ranked = sorted(positions, key=lambda item: (-item.market_value, item.symbol))
    return [item.symbol for item in ranked]


def _by_return(positions: list[Holding], *, best_first: bool) -> list[str]:
    """Rank by return on cost, no-return positions last, ties by symbol.

    Written from spec 0011 OD-5 rather than from ``return_key``, so inverting
    the production comparison makes this disagree.
    """

    def rank(item: Holding) -> tuple[int, Decimal, str]:
        ratio = return_on_cost(item.unrealized_pl, item.cost_basis)
        if ratio is None:
            return (1, FAR_BEHIND, item.symbol)
        return (0, -ratio if best_first else ratio, item.symbol)

    return [item.symbol for item in sorted(positions, key=rank)]


@pytest.mark.parametrize("sort_by", ["weight", "value"], ids=["weight", "value"])
async def test_the_size_orders_rank_the_largest_position_first(
    tool: HoldingsSummaryTool, tool_context: ToolContext, sort_by: str
) -> None:
    outcome = await tool.run({"sort_by": sort_by}, tool_context)

    assert symbols_of(outcome.data["holdings"]) == _by_size(held(tool_context))


@pytest.mark.parametrize(
    ("sort_by", "best_first"),
    [("gainers", True), ("losers", False)],
    ids=["gainers", "losers"],
)
async def test_the_return_orders_rank_by_profit_on_what_was_paid(
    tool: HoldingsSummaryTool,
    tool_context: ToolContext,
    sort_by: str,
    best_first: bool,
) -> None:
    """OD-5 — by return, not by absolute profit, which position size dominates."""
    outcome = await tool.run({"sort_by": sort_by}, tool_context)
    expected = _by_return(held(tool_context), best_first=best_first)

    assert symbols_of(outcome.data["holdings"]) == expected


@pytest.mark.parametrize("best_first", [True, False], ids=["gainers", "losers"])
def test_a_position_with_no_cost_basis_ranks_last_in_both_directions(
    best_first: bool,
) -> None:
    """OD-5 — it is neither a top gainer nor a top loser, and is not dropped.

    Unreachable from the seed, so it is built here: the conditional inside
    ``return_key`` is not a branch coverage.py can see, which is exactly how
    a documented rule ends up unverified.
    """
    winner = AIRDROP.model_copy(
        update={
            "symbol": "WIN",
            "cost_basis": Decimal("100"),
            "unrealized_pl": FAR_AHEAD,
        }
    )
    loser = AIRDROP.model_copy(
        update={
            "symbol": "LOSE",
            "cost_basis": Decimal("100"),
            "unrealized_pl": FAR_BEHIND,
        }
    )

    ranked = sorted(
        [winner, AIRDROP, loser], key=lambda h: return_key(h, descending=best_first)
    )

    assert ranked[-1].symbol == AIRDROP.symbol


async def test_weight_and_value_are_the_same_order(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """OD-4 — aliases by construction; pinned so nobody 'fixes' one of them."""
    by_weight = await tool.run({"sort_by": "weight"}, tool_context)
    by_value = await tool.run({"sort_by": "value"}, tool_context)

    assert by_weight.data["holdings"] == by_value.data["holdings"]
    assert SORTERS["weight"] is SORTERS["value"]
