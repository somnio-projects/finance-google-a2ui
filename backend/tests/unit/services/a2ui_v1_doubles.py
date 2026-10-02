"""Builders the A2UI v1.0 service suites share (spec 0053).

The doubles stop at the model, the tools and the portfolio store, exactly as
``agent_doubles`` does for v0.9: the registry, the options models, the view
service and the turn loop are the real ones, so what these suites assert is
what the endpoint emits.
"""

import json
from collections.abc import AsyncIterator, Sequence
from typing import Any

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.core.model import ModelReply
from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.infra.model.null_client import NullModelClient
from app.presentation.registry import REGISTRY
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.a2ui_v1_render_view import RenderViewService
from app.services.a2ui_v1_service import A2uiV1Service
from app.services.a2ui_v1_turn import V1TurnStream
from app.services.surface_action_service import SurfaceActionService
from app.services.view_service import ViewService
from tests.conftest import FROZEN_NOW, FakeFlags, FakeReporter
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, call, make_service
from tests.unit.services.surface_action_doubles import EchoingFlags


def views() -> ViewService:
    """The real view service over the seeded in-memory store."""
    return ViewService(
        provider=InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW)),
        registry=REGISTRY,
    )


def drawing(*intents: RenderIntent) -> list[FakeTool]:
    """One tool per intent, each drawing it, named apart for the registry."""
    tools = [
        FakeTool(outcome=ToolOutcome(data={}, render=intent)) for intent in intents
    ]
    for number, tool in enumerate(tools):
        tool.name = f"tool_{number}"
    return tools


def scripted(tools: Sequence[FakeTool]) -> NullModelClient:
    """A model that calls every tool once, then answers."""
    calls = tuple(call(tool.name, call_id=f"{n}-c") for n, tool in enumerate(tools))
    return NullModelClient([ModelReply(tool_calls=calls), ModelReply(text=ANSWER)])


def build(
    principal: Principal,
    *,
    model: NullModelClient | None = None,
    tools: Sequence[FakeTool] = (),
    flags: FakeFlags | None = None,
) -> tuple[A2uiV1Service, FakeReporter]:
    """Wire the v1.0 adapter as ``deps.a2ui_v1`` does, over the doubles."""
    agent, reporter = make_service(model or NullModelClient(), tools=tools)
    payloads = PayloadRenderer(views=views(), principal=principal)
    actions = SurfaceActionService(
        flags=flags or EchoingFlags(),  # type: ignore[arg-type]
        audit=None,  # type: ignore[arg-type] - no shipped action is audited
        reporter=reporter,
    )
    service = A2uiV1Service(
        turns=V1TurnStream(agent=agent, payloads=payloads, reporter=reporter),
        functions=RenderViewService(
            registry=REGISTRY, payloads=payloads, reporter=reporter
        ),
        actions=actions,
        reporter=reporter,
    )
    return service, reporter


async def call_service(
    principal: Principal,
    context: ToolContext,
    body: object,
    *,
    flags: FakeFlags | None = None,
) -> tuple[Any, NullModelClient]:
    """Answer ``body`` and return the decoded outcome with the model's log.

    Returns:
        The JSON-RPC error body, or every event of the stream — beside the
        null model, whose ``calls`` say whether the model was reached.
    """
    model = NullModelClient()
    service, _ = build(principal, model=model, flags=flags)
    outcome = await service.call(
        body, principal=principal, context=context, task_id="t1", request_id="r1"
    )
    if isinstance(outcome, dict):
        return outcome, model
    return await collect(outcome), model


async def collect(stream: AsyncIterator[str]) -> list[dict[str, Any]]:
    """Decode every SSE ``data:`` line of a stream."""
    return [json.loads(chunk.removeprefix("data: ").strip()) async for chunk in stream]


__all__ = ["build", "call_service", "collect", "drawing", "scripted", "views"]
