"""Spec 0053 AC-5, AC-6, AC-7 — one call, routed to what answers it.

Prose runs a turn, ``callAgentFunction`` never reaches the model (asserted on
the null model's own call log), ``action`` runs the composed turn, and every
refusal is a JSON-RPC body returned before any stream opens.
"""

from app.actions.defined.drill_attribution import DrillAttributionArgs, compose
from app.agent.contracts import ToolContext
from app.core.model import MessageRole
from app.core.principal import Principal
from app.schemas.a2a import INVALID_PARAMS
from app.services.a2a_actions import UNKNOWN_ACTION
from app.services.a2a_dispatch import BAD_PARAMS
from tests.a2ui_v1_envelopes import drill, envelope, example, prose, render_view
from tests.a2ui_v1_schemas import errors
from tests.unit.services.a2ui_v1_doubles import call_service


async def test_prose_runs_a_turn(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, model = await call_service(
        principal, tool_context, prose("what do I hold?")
    )

    assert [event["kind"] for event in events] == [
        "status-update",
        "message",
        "status-update",
    ]
    assert {event["contextId"] for event in events} == {"ctx-1"}
    assert len(model.calls) == 1


async def test_render_view_answers_without_the_model(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, model = await call_service(principal, tool_context, render_view())

    assert model.calls == []
    assert [event["kind"] for event in events] == [
        "status-update",
        "artifact-update",
        "status-update",
    ]
    artifact = events[1]["artifact"]
    assert artifact["artifactId"] == "turn-7f3a-0-call-01"
    data = artifact["parts"][0]["data"]
    assert [next(iter(m.keys() - {"version"})) for m in data] == [
        "agentFunctionResponse",
        "updateDataModel",
    ]
    assert errors("agent_to_renderer_list.json", data) == []
    assert events[-1]["status"] == {"state": "completed"}


async def test_an_action_runs_the_turn_the_backend_composed(
    principal: Principal, tool_context: ToolContext
) -> None:
    events, model = await call_service(principal, tool_context, drill())

    assert events[0]["status"] == {"state": "working"}
    sent = [m for m in model.calls[0].messages if m.role is MessageRole.USER]
    expected = compose(DrillAttributionArgs.model_validate({"driver": "LINK"}))
    assert sent[-1].text == expected


async def test_an_unknown_action_name_is_refused(
    principal: Principal, tool_context: ToolContext
) -> None:
    body = drill()
    body["params"]["message"]["parts"][0]["data"][0]["action"]["name"] = "sell_all"

    outcome, _ = await call_service(principal, tool_context, body)

    assert outcome["error"] == {"code": INVALID_PARAMS, "message": UNKNOWN_ACTION}


async def test_a_message_carrying_both_kinds_is_refused(
    principal: Principal, tool_context: ToolContext
) -> None:
    part = example("action.drill_attribution.json")
    function = example("call_agent_function.render_view.json")["data"][0]
    part["data"][0]["callAgentFunction"] = function["callAgentFunction"]

    outcome, _ = await call_service(principal, tool_context, envelope(part))

    assert outcome["error"] == {"code": INVALID_PARAMS, "message": BAD_PARAMS}
