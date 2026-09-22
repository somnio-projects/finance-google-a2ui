"""Spec 0033 OD-3 — the drill a tapped bar sends, as a whole scripted turn.

Flow A's D2 state: a tapped bar recomposes the driver's card (spec 0032). The
turn runs the real ``driver_detail`` tool over the seeded portfolio; a market
symbol the seed does not hold draws nothing and says so.
"""

from app.agent.contracts import ToolContext
from app.infra.model.demo_script import DEMO_SCRIPTS
from app.infra.model.script import TOOLS_FAILED_MESSAGE, normalise
from tests.unit.services.test_scripted_turns import run


def composed(symbol: str) -> str:
    """The prompt ``drill.attribution.v1`` composes for ``symbol``."""
    return (
        f"Break down the contribution of {symbol} in more detail for the same "
        "window, and show the result."
    )


async def test_a_tapped_bar_opens_the_drivers_card_for_today(
    tool_context: ToolContext,
) -> None:
    """Flow A's D2: the drill composes ``attribution.driver.v1`` (spec 0032)."""
    result, _, _ = await run(composed("NVDA"), tool_context)

    (intent,) = result.render_intents
    assert intent.view == "attribution.driver.v1"
    assert intent.options == {"symbol": "NVDA"}
    assert result.message.startswith("NVIDIA Corp (NVDA) contributed ")
    assert "today" in result.message


async def test_a_drill_on_a_symbol_the_seed_does_not_hold_says_so(
    tool_context: ToolContext,
) -> None:
    """The tool answers ``held: false``; the script's ``otherwise`` is said."""
    script = DEMO_SCRIPTS[normalise(composed("AMD"))]

    result, _, reporter = await run(composed("AMD"), tool_context)

    assert result.render_intents == ()
    assert result.tool_calls == 1
    assert result.message == script.otherwise
    assert result.message != TOOLS_FAILED_MESSAGE
    assert "AMD is not held" in result.message
    assert reporter.exceptions == []
