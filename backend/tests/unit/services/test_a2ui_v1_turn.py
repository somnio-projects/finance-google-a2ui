"""Spec 0053 AC-3, AC-4 — a turn's intents become v1.0 surfaces, in order.

The loop is the real one, over the real registry and view service; only the
model and the tools are scripted. Every emitted ``DataPart`` is validated
against the vendored schemas with the generated catalog, and every payload is
compared with what the view service renders for the same view and options —
the figure on the REST read (AC-3).
"""

from typing import Any

from app.agent.contracts import RenderIntent, ToolContext
from app.core.principal import Principal
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.a2ui_v1_turn import WIRE_METRIC, WIRE_TAGS, V1TurnStream
from tests.a2ui_v1_schemas import errors
from tests.unit.services.a2ui_v1_doubles import collect, drawing, scripted, views
from tests.unit.services.agent_doubles import ANSWER, make_service

SUMMARY = RenderIntent(view="portfolio.summary.v1", options={"range": "1m"})
TICKET = RenderIntent(view="order.ticket.v2", options={})
PAYOFF = RenderIntent(view="payoff.curve.v1", options={})


async def _turn(
    principal: Principal, context: ToolContext, *intents: RenderIntent
) -> tuple[list[dict[str, Any]], list[tuple[str, dict[str, str]]]]:
    tools = drawing(*intents)
    agent, reporter = make_service(scripted(tools), tools=tools)
    stream = V1TurnStream(
        agent=agent,
        payloads=PayloadRenderer(views=views(), principal=principal),
        reporter=reporter,
    )
    events = await collect(
        stream.stream(prompt="hi", task_id="t1", context_id="c1", context=context)
    )
    return events, reporter.metrics


def _parts(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        event["artifact"]["parts"][0]
        for event in events
        if event["kind"] == "artifact-update"
    ]


async def _rest(principal: Principal, intent: RenderIntent) -> dict[str, Any]:
    service = views()
    portfolio = await service.portfolio(principal)
    payload = service.render_one(portfolio, view=intent.view, options=intent.options)
    return payload.model_dump(mode="json")


async def test_n_intents_stream_n_surfaces_in_order(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, metrics = await _turn(principal, tool_context, SUMMARY, TICKET)

    kinds = [event["kind"] for event in events]
    assert kinds == [
        "status-update",
        "artifact-update",
        "artifact-update",
        "message",
        "status-update",
    ]
    surfaces = [part["data"][0]["createSurface"] for part in _parts(events)]
    assert [s["surfaceId"] for s in surfaces] == ["t1-0", "t1-1"]
    assert [s["components"][0]["component"] for s in surfaces] == [
        "PortfolioSummary",
        "MultiLegOrderTicket",
    ]
    assert events[1]["artifact"]["artifactId"] == "t1-0"
    assert (WIRE_METRIC, WIRE_TAGS) in metrics


async def test_every_payload_is_the_rest_payload_for_its_view_and_options(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, _ = await _turn(principal, tool_context, SUMMARY)

    root = _parts(events)[0]["data"][0]["createSurface"]["dataModel"]["root"]
    assert root["view"] == SUMMARY.view
    assert root["options"] == {"range": "1m"}
    assert root["payload"] == await _rest(principal, SUMMARY)


async def test_every_emitted_part_validates_against_the_v1_schemas(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, _ = await _turn(principal, tool_context, SUMMARY, TICKET, PAYOFF)

    for part in _parts(events):
        assert errors("agent_to_renderer_list.json", part["data"]) == []


async def test_a_ticket_and_its_payoff_are_one_surface(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, _ = await _turn(principal, tool_context, TICKET, PAYOFF)

    parts = _parts(events)
    assert len(parts) == 1
    surface = parts[0]["data"][0]["createSurface"]
    assert surface["components"][0]["children"] == ["payoff"]
    assert surface["dataModel"]["payoff"]["payload"] == await _rest(principal, PAYOFF)


async def test_the_terminal_message_carries_no_render_intents(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, _ = await _turn(principal, tool_context, SUMMARY)

    message = next(event for event in events if event["kind"] == "message")
    assert "renderIntents" not in message
    assert message["parts"] == [{"kind": "text", "text": ANSWER}]
    assert events[-1]["status"] == {"state": "input_required"}


async def test_a_turn_without_surfaces_completes(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, _ = await _turn(principal, tool_context)

    assert [event["kind"] for event in events][1:] == ["message", "status-update"]
    assert events[-1]["status"] == {"state": "completed"}
