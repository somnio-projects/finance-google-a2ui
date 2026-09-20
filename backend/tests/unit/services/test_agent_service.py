"""Spec 0006 AC-9/AC-10 — the turn loop and its iteration bound."""

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.prompt import ITERATION_LIMIT_MESSAGE
from app.core.model import MessageRole, ModelMessage, ModelReply, ToolSpec
from app.infra.model.null_client import NullModelClient
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import (
    ANSWER,
    TEST_PROMPT,
    call,
    make_service,
    tool_results,
)


async def test_run_turn_without_tool_calls_returns_the_models_answer(
    tool_context: ToolContext,
) -> None:
    model = NullModelClient([ModelReply(text=ANSWER)])
    service, reporter = make_service(model)

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.message == ANSWER
    assert result.iterations == 1
    assert result.tool_calls == 0
    assert result.render_intents == ()
    assert result.truncated is False
    assert reporter.exceptions == []


async def test_run_turn_sends_the_system_prompt_history_and_tool_schemas(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    model = NullModelClient([ModelReply(text=ANSWER)])
    service, _ = make_service(model, tools=[fake_tool])
    earlier = ModelMessage(role=MessageRole.USER, text="earlier question")

    await service.run_turn(prompt="hi", history=[earlier], context=tool_context)

    sent = model.calls[0]
    assert sent.system == TEST_PROMPT
    assert sent.messages[0] == earlier
    assert sent.messages[-1] == ModelMessage(role=MessageRole.USER, text="hi")
    assert sent.tools == (
        ToolSpec(
            name=fake_tool.name,
            description=fake_tool.description,
            parameters=fake_tool.parameters,
        ),
    )


async def test_run_turn_executes_a_single_tool_call_and_feeds_the_result_back(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    model = NullModelClient([ModelReply(tool_calls=(call(),)), ModelReply(text=ANSWER)])
    service, reporter = make_service(model, tools=[fake_tool])

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.message == ANSWER
    assert result.tool_calls == 1
    assert result.iterations == 2
    assert result.render_intents == (fake_tool.outcome.render,)
    assert fake_tool.seen == [{"top_n": 1}]
    assert tool_results(model) == [fake_tool.outcome.data]
    assert reporter.exceptions == []


async def test_run_turn_executes_several_tool_calls_from_one_reply(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    second = FakeTool(
        outcome=ToolOutcome(
            data={"otherDisplay": "$2.00"},
            render=RenderIntent(view="taxlots.table.v1", options={}),
        )
    )
    second.name = "other_tool"
    model = NullModelClient(
        [
            ModelReply(
                tool_calls=(
                    call(call_id="0-fake"),
                    call("other_tool", call_id="1-other"),
                )
            ),
            ModelReply(text=ANSWER),
        ]
    )
    service, _ = make_service(model, tools=[fake_tool, second])

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.tool_calls == 2
    assert result.iterations == 2
    assert result.render_intents == (fake_tool.outcome.render, second.outcome.render)
    assert tool_results(model) == [fake_tool.outcome.data, second.outcome.data]


async def test_run_turn_collects_no_intent_from_a_tool_that_renders_nothing(
    tool_context: ToolContext,
) -> None:
    silent = FakeTool(outcome=ToolOutcome(data={"totalDisplay": "$0.00"}))
    model = NullModelClient([ModelReply(tool_calls=(call(),)), ModelReply(text=ANSWER)])
    service, _ = make_service(model, tools=[silent])

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.render_intents == ()
    assert tool_results(model) == [silent.outcome.data]


async def test_run_turn_stops_at_the_iteration_bound_and_marks_it_truncated(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    # The script never stops asking for a tool: only the bound can end the turn.
    model = NullModelClient([ModelReply(tool_calls=(call(),))])
    service, reporter = make_service(model, tools=[fake_tool], max_iterations=2)

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.truncated is True
    assert result.message == ITERATION_LIMIT_MESSAGE
    assert result.iterations == 2
    assert result.tool_calls == 2
    assert len(model.calls) == 2
    assert reporter.exceptions == []
