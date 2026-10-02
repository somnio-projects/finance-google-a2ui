"""Spec 0052 — what ``compare_lot_methods`` answers, and what it refuses.

The tool exists because `scenario.comparison.v1` had no turn: it was
registered, served and gated, and nothing drew it. These tests hold the two
halves of that fix — the payload the model reads, and the refusals — while
`test_compare_render.py` holds the intent that reaches the card.
"""

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.compare_methods import CompareLotMethodsTool
from app.agent.tools.compare_request import DEFAULT_METHODS, CompareMethodsArguments
from app.agent.tools.compare_rows import methods_display
from tests.unit.agent.tools.compare_fixtures import (
    THREE_QUARTERS,
    TWENTY_THOUSAND,
    columns,
    subject,
)
from tests.unit.agent.tools.compare_fixtures import tool as tool

__all__ = ["tool"]


async def test_one_column_per_method_in_the_order_asked_for(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-2 — the comparison is the methods, so the methods are the columns."""
    outcome = await tool.run(
        {**THREE_QUARTERS, "methods": ["HIFO", "FIFO"]}, tool_context
    )

    assert [row["lotMethod"] for row in columns(outcome.data["columns"])] == [
        "HIFO",
        "FIFO",
    ]


async def test_the_methods_disagree_on_what_the_sale_realises(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-2 — a card whose columns all match would claim nothing.

    Asserted as a **relationship between the columns**, not as a figure: the
    whole premise is that the method, and only the method, moved the result,
    so the columns must share the sale and differ on the gain.
    """
    outcome = await tool.run(TWENTY_THOUSAND, tool_context)
    rows = columns(outcome.data["columns"])

    assert len({row["proceedsDisplay"] for row in rows}) == 1
    assert len({row["realizedPlDisplay"] for row in rows}) > 1


async def test_every_column_costs_the_same_sale_as_the_subject(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-3 — the sentence's premise and the columns cannot disagree.

    The subject block is what the answer says out loud; if it named a size or
    a price a column did not use, the sentence would describe a different
    sale from the one drawn under it.
    """
    outcome = await tool.run(TWENTY_THOUSAND, tool_context)
    said = subject(outcome.data["subject"])
    rows = columns(outcome.data["columns"])

    assert {row["symbol"] for row in rows} == {said["symbol"]}
    assert {row["quantityDisplay"] for row in rows} == {said["quantityDisplay"]}
    assert {row["priceDisplay"] for row in rows} == {said["priceDisplay"]}


async def test_the_sentence_names_the_methods_it_compared(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-3 — read from the columns, not from a literal in this file."""
    outcome = await tool.run(TWENTY_THOUSAND, tool_context)
    rows = columns(outcome.data["columns"])

    assert subject(outcome.data["subject"])["methodsDisplay"] == methods_display(
        [str(row["lotMethod"]) for row in rows]
    )


@pytest.mark.parametrize(
    ("names", "expected"),
    [
        (["FIFO", "LIFO"], "FIFO and LIFO"),
        (list(DEFAULT_METHODS), "FIFO, LIFO and HIFO"),
    ],
    ids=["two", "three"],
)
def test_the_method_list_reads_as_a_sentence(names: list[str], expected: str) -> None:
    """AC-3 — the client never assembles this list, so the server must."""
    assert methods_display(names) == expected


async def test_selling_more_than_is_held_answers_instead_of_failing(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-5 — it fails every column identically, so there is no card.

    The same shape ``simulate_sale`` uses: a raising tool would reach the
    model as ``{"error": "tool-failed"}`` and the one number that makes the
    answer helpful would be gone. The absent render intent is the other half
    — a comparison under "you hold fewer units than that" would be three
    empty columns pretending to be a decision.
    """
    outcome = await tool.run({"symbol": "BTC", "quantity": "3"}, tool_context)

    assert outcome.data["error"] == "position-too-small"
    assert outcome.data["heldDisplay"] == "2.1"
    assert "columns" not in outcome.data
    assert outcome.render is None


def test_a_repeated_method_is_refused_rather_than_deduplicated() -> None:
    """AC-4 — two identical columns would claim a difference that is not there."""
    with pytest.raises(ValidationError, match="methods must be distinct"):
        CompareMethodsArguments(symbol="BTC", quantity="0.75", methods=("FIFO", "FIFO"))


def test_a_single_method_is_not_a_comparison() -> None:
    """AC-4 — the refusal is structural: ``min_length=2`` on the field."""
    with pytest.raises(ValidationError, match="at least 2 items"):
        CompareMethodsArguments(symbol="BTC", quantity="0.75", methods=("FIFO",))


def test_the_model_cannot_name_a_tax_rate(tool: CompareLotMethodsTool) -> None:
    """AC-6, GGU-134 — the printed assumption must not be model-authored.

    ``extra="forbid"`` is what enforces it, so this asserts the *effect* of
    the design rather than the absence of a field: a rate the model chose
    would reach the card as the rate it claims to have costed with.
    """
    with pytest.raises(ValidationError, match="Extra inputs are not permitted"):
        CompareMethodsArguments.model_validate(
            {**THREE_QUARTERS, "short_term_rate": "0.1"}
        )
    assert "rate" not in tool.parameters["properties"]  # type: ignore[index]
