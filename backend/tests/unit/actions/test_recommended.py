"""``recommended`` — the chips a turn offers next (spec 0029 OD-1)."""

import pytest

from app.actions.suggestions import (
    DECLARED_KEYS,
    SUGGESTIONS,
    recommended,
    suggestion_prompt,
)


@pytest.mark.parametrize("key", DECLARED_KEYS)
def test_a_turn_never_offers_the_question_it_just_answered(key: str) -> None:
    offered = recommended(suggestion_prompt(key))

    assert key not in offered
    assert offered == tuple(other for other in SUGGESTIONS if other != key)


def test_a_free_text_turn_is_offered_every_curated_chip_in_table_order() -> None:
    assert recommended("why did I move?") == tuple(SUGGESTIONS)


def test_nothing_offered_is_outside_the_declared_keys() -> None:
    assert set(recommended("anything")) <= set(DECLARED_KEYS)
