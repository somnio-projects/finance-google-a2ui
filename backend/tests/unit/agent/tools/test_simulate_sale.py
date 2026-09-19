"""Spec 0013 — what the sell-scenario tool answers.

The lot walk itself is `tests/unit/domain/test_sales.py`, and how a size is
named is `test_simulate_sale_sizes.py`. This file is the payload: the schema,
the formatting invariant, determinism and the absent render intent.
"""

from decimal import Decimal

from app.agent.contracts import ToolContext
from app.agent.tools.simulate_sale import SimulateSaleTool
from app.core.display import money_display
from app.core.model import ToolSpec
from app.domain.sales import simulate_sale
from app.domain.terms import LotTerm
from tests.unit.agent.tools.sale_fixtures import (
    DISPLAY_KEY,
    HALF_A_BITCOIN,
    NOT_A_FIGURE,
    block,
    lots,
    tool,
)
from tests.unit.agent.tools.sale_payload import FIFO_HALF_BITCOIN

__all__ = ["tool"]


async def test_it_describes_itself_for_the_model_to_choose_by(
    tool: SimulateSaleTool,
) -> None:
    """AC-1 — the description and the schema are what the model picks from."""
    assert tool.name == "simulate_sale"
    assert "HIFO" in tool.description
    properties = tool.parameters["properties"]
    assert isinstance(properties, dict)
    assert set(properties) == {"symbol", "quantity", "amount_usd", "lot_method"}
    assert tool.parameters["additionalProperties"] is False


async def test_its_description_fits_what_the_model_is_told(
    tool: SimulateSaleTool,
) -> None:
    """``ToolSpec`` bounds a description at 512 characters; this one is checked."""
    spec = ToolSpec(
        name=tool.name, description=tool.description, parameters=tool.parameters
    )

    assert len(spec.description) <= 512


async def test_the_published_example_is_the_answer_it_publishes(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-2, AC-5 — every string of spec 0013 §3, pinned where it is wired.

    A literal oracle rather than a rebuild from the domain. The domain's own
    invariants live in ``test_sales.py``, and they hold just as well with two
    summary figures swapped: this is the only test that would notice
    ``shortTermPlDisplay`` carrying the long-term gain.
    """
    portfolio = tool_context.portfolios.get(tool_context.subject)

    outcome = await tool.run(HALF_A_BITCOIN, tool_context)

    assert outcome.data["asOf"] == portfolio.as_of.isoformat()
    assert outcome.data["summary"] == FIFO_HALF_BITCOIN["summary"]
    assert outcome.data["remaining"] == FIFO_HALF_BITCOIN["remaining"]
    assert outcome.data["lots"] == FIFO_HALF_BITCOIN["lots"]


async def test_the_summary_is_the_domain_s_own_answer(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-2 — the payload reports the walk; it does not recompute it."""
    portfolio = tool_context.portfolios.get(tool_context.subject)
    expected = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.5"))

    outcome = await tool.run(HALF_A_BITCOIN, tool_context)

    summary = block(outcome.data["summary"])
    assert summary["proceedsDisplay"] == money_display(expected.proceeds)
    assert summary["costBasisDisplay"] == money_display(expected.cost_basis)
    assert summary["shortTermLots"] == expected.lots_in(LotTerm.SHORT)
    assert summary["longTermLots"] == expected.lots_in(LotTerm.LONG)
    assert len(lots(outcome.data["lots"])) == len(expected.consumed)


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-5 — no bare number escapes, in the summary, the lots or the leftover."""
    outcome = await tool.run(HALF_A_BITCOIN, tool_context)
    sections = [
        block(outcome.data["summary"]),
        block(outcome.data["remaining"]),
        *lots(outcome.data["lots"]),
    ]

    for section in sections:
        for key, value in section.items():
            assert DISPLAY_KEY.search(key) or key in NOT_A_FIGURE
            assert isinstance(value, str) or key in NOT_A_FIGURE


async def test_the_same_question_twice_gives_the_same_answer(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-7 — deterministic for a fixed seed, a fixed clock and fixed arguments."""
    first = await tool.run({**HALF_A_BITCOIN, "lot_method": "HIFO"}, tool_context)
    second = await tool.run({**HALF_A_BITCOIN, "lot_method": "HIFO"}, tool_context)

    assert first.data == second.data


async def test_it_asks_for_no_chart_because_none_fits(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-8, OD-5 — no registered projection renders a sell scenario."""
    outcome = await tool.run(HALF_A_BITCOIN, tool_context)

    assert outcome.render is None
    assert "view" not in outcome.data


async def test_the_lot_method_changes_which_lots_the_answer_names(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-3 at the tool's boundary — the argument reaches the walk.

    ETH rather than BTC: its older lot is also its dearer one, so FIFO and
    LIFO consume different lots and the difference is visible in one call.
    """
    oldest_first = await tool.run({"symbol": "ETH", "quantity": "2.5"}, tool_context)
    newest_first = await tool.run(
        {"symbol": "ETH", "quantity": "2.5", "lot_method": "LIFO"}, tool_context
    )

    assert [row["lotId"] for row in lots(oldest_first.data["lots"])] == ["lot-eth-01"]
    assert [row["lotId"] for row in lots(newest_first.data["lots"])] == [
        "lot-eth-02",
        "lot-eth-01",
    ]
