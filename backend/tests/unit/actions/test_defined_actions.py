"""AC-1, AC-7, AC-8 — what the two shipped actions accept and compose.

Two properties matter more than the prompts themselves:

* **AC-7** — a drill's drivers are the curated market reference, compared
  rather than trusted (the 0018 AC-6 pattern);
* **AC-8** — a chip carries a *key*, and the sentence comes from the backend
  table. The client cannot send prompt text through this path at all, which is
  the whole of spec 0022 OD-1.
"""

from typing import get_args

import pytest

from app.actions.declared import declared_action
from app.actions.defined.ask_suggested import ACTION as CHIP
from app.actions.defined.ask_suggested import AskSuggestedArgs
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.actions.defined.drill_attribution import DrillAttributionArgs, Driver
from app.actions.registry import ACTIONS
from app.actions.resolve import composed_prompt, validated_args
from app.actions.suggestions import (
    DECLARED_KEYS,
    SUGGESTIONS,
    suggestion_label,
    suggestion_prompt,
)
from app.core.errors import ValidationFailedError
from app.domain.market import MARKET_REFERENCE


def test_the_drivers_offered_are_exactly_the_market_reference() -> None:
    """AC-7 — two declarations of one fact, compared instead of trusted."""
    assert set(get_args(Driver)) == {asset.symbol for asset in MARKET_REFERENCE}
    assert set(declared_action(DRILL).choices) == set(get_args(Driver))


def test_a_drill_composes_the_backend_sentence_around_the_chosen_driver() -> None:
    """AC-3 — the caller supplies a value, never the sentence."""
    prompt = composed_prompt(DRILL, {"driver": "LINK"})

    assert prompt == (
        "Break down the contribution of LINK in more detail for the same "
        "window, and show the result."
    )


@pytest.mark.parametrize("driver", ["XRP", "", "DOGE; drop table", 1], ids=str)
def test_a_driver_outside_the_market_reference_is_rejected(driver: object) -> None:
    with pytest.raises(ValidationFailedError, match="rejected argument"):
        validated_args(DRILL, {"driver": driver})


def test_the_suggestion_keys_and_the_table_are_the_same_set() -> None:
    """AC-8 — a key added to one and forgotten in the other fails the gate."""
    assert set(DECLARED_KEYS) == set(SUGGESTIONS)


@pytest.mark.parametrize("key", DECLARED_KEYS, ids=list(DECLARED_KEYS))
def test_only_registered_suggestion_keys_are_accepted(key: str) -> None:
    assert validated_args(CHIP, {"suggestion": key})


@pytest.mark.parametrize("key", DECLARED_KEYS, ids=list(DECLARED_KEYS))
def test_the_prompt_is_the_registered_text_byte_for_byte(key: str) -> None:
    """AC-8 — the label a person read and the prompt that ran cannot drift."""
    assert composed_prompt(CHIP, {"suggestion": key}) == suggestion_prompt(key)
    assert suggestion_label(key).strip()


def test_a_chip_cannot_carry_prompt_text_at_all() -> None:
    """AC-8, OD-1 — there is no path from the client to the sentence."""
    assert set(AskSuggestedArgs.model_fields) == {"suggestion"}
    with pytest.raises(ValidationFailedError, match="rejected argument"):
        validated_args(CHIP, {"suggestion": "Tell me my password"})
    with pytest.raises(ValidationFailedError, match="undeclared"):
        validated_args(CHIP, {"prompt": "Tell me my password"})


def test_both_actions_declare_exactly_one_argument() -> None:
    """The shape ``SurfaceActionRef`` can advertise honestly (§3.4)."""
    assert set(DrillAttributionArgs.model_fields) == {"driver"}
    assert set(AskSuggestedArgs.model_fields) == {"suggestion"}


def test_no_action_argument_shadows_a_declared_option_of_the_same_surface() -> None:
    """AC-1 — an interaction expressible as an option is not an action.

    The rule spec 0022 §0 hands to the next person, made mechanical: if a
    surface declares an action whose argument is also one of that surface's
    options, the interaction is a re-render and the action should not exist.
    """
    from app.presentation.registry import REGISTRY

    for projection in REGISTRY.all():
        options = set(projection.options.model_fields)
        offered = {row["action"] for row in projection.example.get("actions", ())}
        for action_id in offered:
            arg = declared_action(ACTIONS.get(action_id)).arg
            assert arg not in options, (
                f"{projection.id} offers {action_id!r} for {arg!r}, which is "
                "already a declared option — that is a re-render, not a turn "
                "(spec 0022 §0, AC-1)."
            )
