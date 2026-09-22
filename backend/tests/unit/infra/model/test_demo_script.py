"""Spec 0033 AC-4 — the table names only prompts and tools the backend owns.

Two declarations of each fact, compared: the chip keys against the curated
suggestion table, the drill keys against the market reference, and every tool
name against the discovered registry. A comment claiming they agree is what
this file replaces.
"""

import pytest

from app.actions.suggestions import DECLARED_KEYS, SUGGESTIONS
from app.agent.registry import load_tools
from app.domain.market import MARKET_REFERENCE
from app.infra.model.demo_script import (
    CHIP_SCRIPTS,
    DEMO_SCRIPTS,
    FLOW_A,
    FLOW_B,
    FLOW_C,
    FLOW_SCRIPTS,
)
from app.infra.model.script import PLACEHOLDER, normalise

REGISTERED = load_tools().names()


def test_every_curated_chip_has_a_script_and_nothing_else_does() -> None:
    assert tuple(CHIP_SCRIPTS) == DECLARED_KEYS


@pytest.mark.parametrize("key", DECLARED_KEYS, ids=DECLARED_KEYS)
def test_the_chips_registered_prompt_is_a_key_of_the_table(key: str) -> None:
    assert DEMO_SCRIPTS[normalise(SUGGESTIONS[key][1])] is CHIP_SCRIPTS[key]


@pytest.mark.parametrize(
    "prompt", [FLOW_A, FLOW_B, FLOW_C], ids=["flow-a", "flow-b", "flow-c"]
)
def test_the_designs_three_questions_are_keys_of_the_table(prompt: str) -> None:
    assert DEMO_SCRIPTS[normalise(prompt)] is FLOW_SCRIPTS[prompt]


@pytest.mark.parametrize(
    "symbol",
    [asset.symbol for asset in MARKET_REFERENCE],
    ids=[asset.symbol for asset in MARKET_REFERENCE],
)
def test_a_drill_on_every_market_symbol_is_a_key_of_the_table(symbol: str) -> None:
    composed = (
        f"Break down the contribution of {symbol} in more detail for the "
        "same window, and show the result."
    )

    script = DEMO_SCRIPTS[normalise(composed)]

    assert [call.arguments for call in script.calls] == [
        {"window": "7d", "symbols": [symbol]}
    ]


def test_the_table_holds_exactly_the_three_sources() -> None:
    expected = len(FLOW_SCRIPTS) + len(CHIP_SCRIPTS) + len(MARKET_REFERENCE)

    assert len(DEMO_SCRIPTS) == expected


@pytest.mark.parametrize("key", sorted(DEMO_SCRIPTS), ids=sorted(DEMO_SCRIPTS))
def test_every_script_calls_at_least_one_registered_tool(key: str) -> None:
    script = DEMO_SCRIPTS[key]

    assert script.calls, "a script with nothing to call would loop to the bound"
    assert all(call.name in REGISTERED for call in script.calls)


@pytest.mark.parametrize("key", sorted(DEMO_SCRIPTS), ids=sorted(DEMO_SCRIPTS))
def test_every_hole_in_a_sentence_names_a_display_string_or_a_token(key: str) -> None:
    """A figure only ever enters a sentence as a ``*Display`` copy (OD-2)."""
    holes = PLACEHOLDER.findall(DEMO_SCRIPTS[key].answer)

    assert holes, "a scripted sentence with no hole would be a sentence with no data"
    for hole in holes:
        leaf = hole.rsplit(".", maxsplit=1)[-1]
        assert leaf.endswith("Display") or leaf in {
            "trend",
            "symbol",
            "lotMethod",
            "name",
        }, hole
