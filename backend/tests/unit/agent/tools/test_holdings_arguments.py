"""Spec 0011 AC-4 — what the holdings tool accepts, and what it refuses.

The orders themselves are ``test_holdings_ordering``; this file is the
boundary: the filter, the cut, the bounds the model is told about, and the
arguments that never reach the portfolio at all.
"""

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_query import (
    MAX_SYMBOLS,
    MAX_TICKER,
    PARAMETERS,
    HoldingsSummaryArguments,
)
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from tests.unit.agent.tools.holdings_fixtures import held, rows, symbols_of
from tests.unit.agent.tools.holdings_fixtures import tool as tool


@pytest.mark.parametrize(
    "asked", [["btc"], [" BTC "], ["BTC"]], ids=["lowercase", "padded", "canonical"]
)
async def test_the_symbols_filter_normalises_what_it_was_asked_for(
    tool: HoldingsSummaryTool, tool_context: ToolContext, asked: list[str]
) -> None:
    """One ask, however the model spelled it (spec 0003 AC-4)."""
    outcome = await tool.run({"symbols": asked}, tool_context)

    assert symbols_of(outcome.data["holdings"]) == ["BTC"]


async def test_an_unknown_symbol_matches_nothing_rather_than_failing(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """A ticker the portfolio does not hold is an empty answer, not an error."""
    outcome = await tool.run({"symbols": ["ZZZ"]}, tool_context)
    totals = outcome.data["totals"]

    assert rows(outcome.data["holdings"]) == []
    assert isinstance(totals, dict)
    assert totals["count"] == len(held(tool_context))


async def test_top_n_cuts_after_sorting_not_before(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """The first row of a trimmed call is the first row of the full one."""
    full = await tool.run({"sort_by": "losers"}, tool_context)
    trimmed = await tool.run({"sort_by": "losers", "top_n": 1}, tool_context)

    assert rows(trimmed.data["holdings"]) == rows(full.data["holdings"])[:1]


def test_the_schema_the_model_reads_carries_the_same_bounds() -> None:
    """The model reads ``PARAMETERS``; pydantic enforces the model class.

    A bound declared in one and missing from the other is the failure this
    catches: the model would be told 'ten characters' and the boundary would
    accept five thousand.
    """
    enforced = HoldingsSummaryArguments.model_json_schema()["properties"]
    advertised = PARAMETERS["properties"]
    assert isinstance(advertised, dict)

    symbols = advertised["symbols"]
    assert isinstance(symbols, dict)
    assert symbols["maxItems"] == MAX_SYMBOLS
    item = symbols["items"]
    assert isinstance(item, dict)
    assert item["maxLength"] == MAX_TICKER
    assert enforced["symbols"]["anyOf"][0]["items"]["maxLength"] == MAX_TICKER
    assert enforced["symbols"]["anyOf"][0]["items"]["pattern"] == item["pattern"]


@pytest.mark.parametrize(
    "arguments",
    [
        {"top_n": 0},
        {"top_n": 99},
        {"unknown": 1},
        {"top_n": "two"},
        {"sort_by": "alphabetical"},
        {"symbols": [f"SY{index}" for index in range(21)]},
        {"symbols": ["X" * 5000]},
        {"symbols": ["!!!"]},
    ],
    ids=[
        "below_bound",
        "above_bound",
        "undeclared_option",
        "wrong_type",
        "unknown_order",
        "too_many_symbols",
        "oversized_ticker",
        "ticker_that_is_not_a_ticker",
    ],
)
async def test_run_rejects_arguments_the_schema_does_not_declare(
    tool: HoldingsSummaryTool,
    tool_context: ToolContext,
    arguments: dict[str, object],
) -> None:
    """OD-7 — rejected, never coerced into the default."""
    with pytest.raises(ValidationError, match=r"top_n|unknown|sort_by|symbols"):
        await tool.run(arguments, tool_context)
