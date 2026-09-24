"""Spec 0031 AC-7 — what ``draft_order`` composes, and what it refuses.

The figures are the same literals `test_order_ticket_v2` pins, because the
tool and the projection read one domain statement: the words the model says
and the surface it renders must describe one order.
"""

from collections.abc import Mapping
from typing import Final, get_args

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.registry import load_tools
from app.agent.tools.draft_order import NAME, VIEW, DraftOrderTool
from app.domain.baskets import Basket
from tests.unit.agent.tools.payoff_fixtures import block, rows

DESIGN_PROMPT: Final[Mapping[str, object]] = {
    "amount": "10000",
    "basket": "semiconductors",
}


@pytest.fixture
def tool() -> DraftOrderTool:
    """Return the tool under test."""
    return DraftOrderTool()


async def test_the_registry_discovers_it_without_a_shared_list() -> None:
    """The assertion that goes red if ``register(...)`` is removed."""
    registry = load_tools()

    assert NAME in registry.names()
    assert registry.get(NAME) is not None


async def test_it_describes_itself_for_the_model_to_choose_by(
    tool: DraftOrderTool,
) -> None:
    """The description and the schema are what the model picks from."""
    properties = tool.parameters["properties"]

    assert tool.name == NAME
    assert isinstance(properties, dict)
    assert set(properties) == {"amount", "basket", "side"}
    assert tool.parameters["additionalProperties"] is False
    assert "never recompute" in tool.description


async def test_the_design_prompt_composes_the_design_legs(
    tool: DraftOrderTool, tool_context: ToolContext
) -> None:
    """AC-7 — "put about $10k into semiconductors" → NVDA / AVGO / AMD."""
    outcome = await tool.run(DESIGN_PROMPT, tool_context)

    assert outcome.data["legs"] == "NVDA:3,AVGO:2,AMD:14"
    assert [
        (line["symbol"], line["quantityDisplay"], line["notionalDisplay"])
        for line in rows(outcome.data["lines"])
    ] == [
        ("NVDA", "3", "$3,613.98"),
        ("AVGO", "2", "$3,480.00"),
        ("AMD", "14", "$2,333.80"),
    ]
    impact = block(outcome.data["impact"])
    assert impact["totalDisplay"] == "$9,427.78"
    assert impact["unitsDisplay"] == "19"
    assert impact["cashRemainingDisplay"] == "$29,205.44"
    assert rows(impact["weightShifts"]) == [
        {
            "label": "Technology",
            "beforeDisplay": "46.57%",
            "afterDisplay": "48.52%",
        }
    ]


async def test_it_renders_the_ticket_with_the_legs_it_composed(
    tool: DraftOrderTool, tool_context: ToolContext
) -> None:
    """AC-7 — the words and the surface describe one order."""
    outcome = await tool.run(DESIGN_PROMPT, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW == "order.ticket.v2"
    assert outcome.render.options == {"legs": "NVDA:3,AVGO:2,AMD:14", "side": "buy"}


async def test_a_draft_beyond_cash_says_so_in_the_models_words(
    tool: DraftOrderTool, tool_context: ToolContext
) -> None:
    """AC-6 — the shortfall is a string the model copies."""
    outcome = await tool.run({**DESIGN_PROMPT, "amount": "60000"}, tool_context)
    constraints = block(outcome.data["constraints"])

    assert constraints["maxCashDisplay"] == "$38,633.22"
    assert constraints["breach"] == "over_cash"
    assert constraints["shortfallDisplay"] == "$19,971.62"
    assert constraints["message"] == (
        "Exceeds available cash — reduce order by $19,971.62."
    )


async def test_within_cash_carries_no_breach_and_no_sentence(
    tool: DraftOrderTool, tool_context: ToolContext
) -> None:
    constraints = block(
        (await tool.run(DESIGN_PROMPT, tool_context)).data["constraints"]
    )

    assert constraints["breach"] == "none"
    assert constraints["shortfallDisplay"] is None
    assert constraints["message"] is None


@pytest.mark.parametrize("basket", get_args(Basket), ids=get_args(Basket))
async def test_every_basket_composes_a_draft(
    tool: DraftOrderTool, tool_context: ToolContext, basket: str
) -> None:
    outcome = await tool.run({"amount": "10000", "basket": basket}, tool_context)

    assert rows(outcome.data["lines"])
    assert outcome.render is not None


@pytest.mark.parametrize(
    "arguments",
    [
        {"amount": "0", "basket": "semiconductors"},
        {"amount": "10000", "basket": "crypto"},
        {"amount": "-5", "basket": "energy"},
        {"amount": "10000", "basket": "energy", "leverage": 2},
    ],
    ids=["nothing", "unknown-basket", "negative", "undeclared"],
)
async def test_it_refuses_what_it_does_not_declare(
    tool: DraftOrderTool, tool_context: ToolContext, arguments: Mapping[str, object]
) -> None:
    """A rejection the model can retry, never a quiet default."""
    with pytest.raises(ValidationError):
        await tool.run(arguments, tool_context)
