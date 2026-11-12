"""Spec 0056 AC-2, AC-4, AC-6 — the drill pins ``driver_detail``; a chip does not.

The narration is asserted branch by branch because it is the one sentence a
drill turn says with no model behind it: every figure must be a string the
tool returned, and a hole the tool did not fill must never reach the screen.
"""

import pytest

from app.actions.defined.ask_suggested import ACTION as CHIP
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.actions.defined.drill_attribution import DRIVER_TOOL, UNAVAILABLE, narrate
from app.actions.resolve import composed_turn
from app.agent.registry import load_tools

HELD: dict[str, object] = {
    "held": True,
    "symbol": "BTC",
    "name": "Bitcoin",
    "rank": 1,
    "contributionDisplay": "+$1,200.00",
    "priceMovePctDisplay": "+1.20%",
    "priceMoveDisplay": "+$1,300.00",
    "sharesDisplay": "0.92",
    "priceDisplay": "$108,419.40",
    "shareOfDayDisplay": "61.20%",
    "dayGainDisplay": "+$1,960.78",
}


def test_drill_turn_pins_driver_detail_for_the_validated_driver() -> None:
    """AC-4 — the call is built from the validated args, not the raw map."""
    turn = composed_turn(DRILL, {"driver": "LINK"})

    assert turn.direct is not None
    assert (turn.direct.tool, dict(turn.direct.arguments)) == (
        DRIVER_TOOL,
        {"symbol": "LINK"},
    )
    assert "LINK" in turn.prompt


def test_drill_tool_name_is_a_registered_agent_tool() -> None:
    """``app.actions`` spells the name; the agent registry must agree."""
    assert DRIVER_TOOL in load_tools().names()


def test_chip_turn_pins_nothing_and_stays_a_model_turn() -> None:
    """AC-6 — a chip is a question, and answering it is the model's job."""
    assert composed_turn(CHIP, {"suggestion": "allocation"}).direct is None


def test_narrate_held_driver_copies_every_figure_from_the_tool() -> None:
    """AC-4 — the sentence is the tool's strings in backend words."""
    assert narrate(HELD) == (
        "Bitcoin (BTC) contributed +$1,200.00 today: its price moved +1.20% "
        "(+$1,300.00) on 0.92 units at $108,419.40, 61.20% of the day's "
        "+$1,960.78."
    )


def test_narrate_not_held_answers_the_leaf() -> None:
    """The leaf a drill can reach is answered, not failed (spec 0032)."""
    assert narrate({"held": False, "symbol": "XRP"}) == (
        "XRP is not held in this portfolio, so there is no contribution to break down."
    )


@pytest.mark.parametrize(
    "result",
    [
        {"error": "tool-failed"},
        {"held": True, "symbol": "BTC"},
        {"held": False},
    ],
    ids=["error-marker", "held-missing-figures", "leaf-missing-symbol"],
)
def test_narrate_unfilled_hole_says_unavailable(result: dict[str, object]) -> None:
    """A hole with nothing to fill it never reaches the screen."""
    assert narrate(result) == UNAVAILABLE
