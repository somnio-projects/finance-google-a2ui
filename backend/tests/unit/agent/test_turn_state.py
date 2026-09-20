"""Spec 0012 AC-1 — the accumulator that makes incremental emission safe.

``TurnState`` is what a turn hands to telemetry, so draining it wrongly would
either re-emit a surface the client has already drawn or lose one entirely.
Both are silent failures, so the drain is tested on its own.
"""

from app.agent.contracts import RenderIntent, TurnState

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"


def test_take_renders_returns_only_what_arrived_since_the_last_call() -> None:
    state = TurnState()
    state.renders.append(RenderIntent(view=ALLOCATION))

    first = state.take_renders()
    state.renders.append(RenderIntent(view=WATERFALL))
    second = state.take_renders()

    assert first == ((0, RenderIntent(view=ALLOCATION)),)
    assert second == ((1, RenderIntent(view=WATERFALL)),)


def test_take_renders_is_empty_when_nothing_new_arrived() -> None:
    """Every tool call drains; most of them have nothing to drain."""
    state = TurnState()

    assert state.take_renders() == ()
    assert state.emitted == 0


def test_the_full_list_survives_draining() -> None:
    """The turn's result still reports every intent, in order."""
    state = TurnState()
    state.renders.append(RenderIntent(view=ALLOCATION))
    state.take_renders()
    state.renders.append(RenderIntent(view=WATERFALL))
    state.take_renders()

    assert [intent.view for intent in state.renders] == [ALLOCATION, WATERFALL]
