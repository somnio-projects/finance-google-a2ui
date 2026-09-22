"""Spec 0033 AC-2/AC-3 — the scripted client's two steps and its one refusal."""

from app.core.model import MessageRole, ModelMessage, ToolCall, ToolSpec
from app.infra.model.demo_script import FLOW_A
from app.infra.model.null_client import UNCONFIGURED_MESSAGE
from app.infra.model.script import TOOLS_FAILED_MESSAGE, Script, ScriptedCall
from app.infra.model.scripted_client import MODEL_NAME, ScriptedModelClient

SPEC = ToolSpec(name="fake_tool", description="d", parameters={"type": "object"})
TABLE = {
    "hello": Script(
        calls=(
            ScriptedCall("fake_tool", {"top_n": 1}),
            ScriptedCall("other_tool", {}),
        ),
        answer="Worth {totals.marketValueDisplay}.",
    )
}


def user(text: str) -> ModelMessage:
    return ModelMessage(role=MessageRole.USER, text=text)


def tool_result(payload: dict[str, object]) -> ModelMessage:
    return ModelMessage(
        role=MessageRole.TOOL,
        tool_call_id="0-fake_tool",
        tool_name="fake_tool",
        tool_result=payload,
    )


async def test_name_is_what_telemetry_reports() -> None:
    assert ScriptedModelClient(TABLE).name == MODEL_NAME == "scripted"


async def test_generate_records_what_it_was_sent() -> None:
    client = ScriptedModelClient(TABLE)

    await client.generate(system="rules", messages=[user("Hello!")], tools=[SPEC])

    assert client.calls[0].system == "rules"
    assert client.calls[0].messages == (user("Hello!"),)
    assert client.calls[0].tools == (SPEC,)


async def test_generate_with_no_question_answers_the_unconfigured_message() -> None:
    reply = await ScriptedModelClient(TABLE).generate(system="s", messages=[], tools=[])

    assert reply.text == UNCONFIGURED_MESSAGE
    assert reply.tool_calls == ()


async def test_generate_for_a_prompt_outside_the_table_is_honest() -> None:
    client = ScriptedModelClient(TABLE)

    reply = await client.generate(
        system="s", messages=[user("what do I hold?")], tools=[]
    )

    assert reply.text == UNCONFIGURED_MESSAGE
    assert reply.tool_calls == ()


async def test_generate_for_a_scripted_prompt_asks_for_its_calls_in_order() -> None:
    client = ScriptedModelClient(TABLE)

    reply = await client.generate(system="s", messages=[user(" HELLO? ")], tools=[])

    assert reply.text == ""
    assert reply.tool_calls == (
        ToolCall(call_id="0-fake_tool", name="fake_tool", arguments={"top_n": 1}),
        ToolCall(call_id="1-other_tool", name="other_tool", arguments={}),
    )


async def test_generate_after_the_results_says_the_sentence_with_their_strings() -> (
    None
):
    client = ScriptedModelClient(TABLE)
    messages = [
        user("hello"),
        ModelMessage(role=MessageRole.ASSISTANT, tool_calls=()),
        tool_result({"totals": {"marketValueDisplay": "$1.00"}}),
    ]

    reply = await client.generate(system="s", messages=messages, tools=[])

    assert reply.text == "Worth $1.00."
    assert reply.tool_calls == ()


async def test_generate_after_a_failed_tool_says_so_without_a_figure() -> None:
    client = ScriptedModelClient(TABLE)
    messages = [user("hello"), tool_result({"error": "tool-failed"})]

    reply = await client.generate(system="s", messages=messages, tools=[])

    assert reply.text == TOOLS_FAILED_MESSAGE


async def test_generate_reads_only_the_last_question_of_a_history() -> None:
    client = ScriptedModelClient(TABLE)
    messages = [
        user("hello"),
        tool_result({"totals": {"marketValueDisplay": "$1.00"}}),
        ModelMessage(role=MessageRole.ASSISTANT, text="Worth $1.00."),
        user("and now something else"),
    ]

    reply = await client.generate(system="s", messages=messages, tools=[])

    assert reply.text == UNCONFIGURED_MESSAGE


async def test_the_default_table_is_the_demos() -> None:
    reply = await ScriptedModelClient().generate(
        system="s", messages=[user(FLOW_A)], tools=[]
    )

    assert [call.name for call in reply.tool_calls] == ["compute_attribution"]
