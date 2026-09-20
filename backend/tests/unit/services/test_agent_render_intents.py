"""GGU-84 — no surface leaves a turn that the registry has not judged.

These assert the **seam**, not the class. `RenderIntentService` had its own
green unit tests and a provider asserted to be `is not None` while nothing in
the product called either: the hole was between the two, so a test that
constructs the service proves nothing about the turn. Every case here starts
from a tool emitting a render intent and ends at what the turn hands the
client.

The accepted case is parametrised over **the projection registry**, in the
shape of `tests/unit/agent/test_tool_argument_bounds.py`: the next projection
is covered the day it registers, and a chart whose options model the turn
cannot satisfy fails here rather than in a conversation.

ADR-K D-12 is the one to read twice: a rejection must *fall back*, never fail
the turn. A model guessing a view id badly is an ordinary event, and the
conversation still has to show something.
"""

import pytest

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome, TurnResult
from app.agent.events import SurfaceReady
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED
from app.schemas.views import DEFAULT_VIEW
from app.services.render_intent_service import REJECTED_METRIC
from tests.conftest import FakeReporter
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, call, make_service

#: Read once, before any test registers a double into the shared registry.
#: Importing ``app.presentation.views`` is what fills it — run this file alone
#: without that import and the sweep below collects nothing and passes,
#: which is the same shape of hole as the one this ticket fixes.
REGISTERED: list[str] = [projection.id for projection in REGISTRY.all()]

INVENTED = "totally.invented.v9"
ALLOCATION = "holdings.allocation.v1"


async def _turn(
    intent: RenderIntent, context: ToolContext
) -> tuple[TurnResult, FakeReporter, list[SurfaceReady]]:
    """Run one turn whose single tool emits ``intent``.

    Args:
        intent: What the tool asks the client to draw.
        context: The subject-scoped tool context.

    Returns:
        The finished turn, the reporter it recorded through, and the
        surfaces it streamed — both ways an intent leaves a turn.
    """
    tool = FakeTool(outcome=ToolOutcome(data={"answerDisplay": "$1.00"}, render=intent))
    model = NullModelClient([ModelReply(tool_calls=(call(),)), ModelReply(text=ANSWER)])
    service, reporter = make_service(model, tools=[tool])
    surfaces: list[SurfaceReady] = []
    results: list[TurnResult] = []
    async for event in service.run_turn_events(
        prompt="show me", history=[], context=context
    ):
        if isinstance(event, SurfaceReady):
            surfaces.append(event)
        else:
            results.append(event.result)
    return results[-1], reporter, surfaces


def test_every_projection_module_was_swept() -> None:
    """A registry that failed to load would make the sweep below vacuous."""
    assert REGISTERED, "no projection was checked — did the views package load?"
    assert len(REGISTERED) == len(LOADED)


@pytest.mark.parametrize("view", REGISTERED, ids=REGISTERED)
async def test_a_registered_view_reaches_the_client_unchanged(
    view: str, tool_context: ToolContext
) -> None:
    """AC-1: what the registry accepts passes through, and nothing is recorded."""
    result, reporter, surfaces = await _turn(RenderIntent(view=view), tool_context)

    assert result.render_intents == (RenderIntent(view=view),)
    assert [surface.intent.view for surface in surfaces] == [view]
    assert [metric for metric, _ in reporter.metrics] == ["agent.turn"]


async def test_a_view_the_registry_never_heard_of_falls_back_to_the_default(
    tool_context: ToolContext,
) -> None:
    """AC-1, AC-2, AC-3: rejected, recorded, and the turn still answers.

    `totally.invented.v9` is the ticket's own example: it satisfies
    `VIEW_ID_SHAPE`, which is why the regex was never the check.
    """
    result, reporter, surfaces = await _turn(RenderIntent(view=INVENTED), tool_context)

    assert result.render_intents == (RenderIntent(view=DEFAULT_VIEW),)
    assert [surface.intent.view for surface in surfaces] == [DEFAULT_VIEW]
    assert result.message == ANSWER
    assert result.truncated is False
    assert (REJECTED_METRIC, {"view": INVENTED}) in reporter.metrics


@pytest.mark.parametrize(
    "options",
    [{"top_n": 9999}, {"top_n": 0}, {"engraving": "gold"}],
    ids=["above-the-bound", "below-the-bound", "option-the-view-never-declared"],
)
async def test_an_option_a_known_view_refuses_falls_back_too(
    options: dict[str, object], tool_context: ToolContext
) -> None:
    """AC-4: the options model judges, not only the view id.

    The old path looked at the string and stopped, so an out-of-range option
    on a **registered** view reached the client untouched.
    """
    result, reporter, _ = await _turn(
        RenderIntent(view=ALLOCATION, options=options), tool_context
    )

    assert result.render_intents == (RenderIntent(view=DEFAULT_VIEW),)
    assert result.message == ANSWER
    assert (REJECTED_METRIC, {"view": ALLOCATION}) in reporter.metrics


async def test_an_accepted_option_survives_the_seam(
    tool_context: ToolContext,
) -> None:
    """AC-1: validation must not flatten what the tool legitimately chose."""
    intent = RenderIntent(view=ALLOCATION, options={"top_n": 3})

    result, reporter, _ = await _turn(intent, tool_context)

    assert result.render_intents == (intent,)
    assert [metric for metric, _ in reporter.metrics] == ["agent.turn"]
