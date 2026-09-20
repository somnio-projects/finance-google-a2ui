"""Spec 0006 AC-6 — the scripted, network-free model client."""

from app.core.model import MessageRole, ModelMessage, ModelReply, ToolCall, ToolSpec
from app.infra.model.null_client import UNCONFIGURED_MESSAGE, NullModelClient

SPEC = ToolSpec(name="fake_tool", description="d", parameters={"type": "object"})


async def test_generate_without_a_script_answers_the_unconfigured_message() -> None:
    client = NullModelClient()

    reply = await client.generate(system="s", messages=[], tools=[])

    assert reply.text == UNCONFIGURED_MESSAGE
    assert reply.tool_calls == ()


async def test_generate_with_an_empty_script_falls_back_to_the_default() -> None:
    client = NullModelClient([])

    reply = await client.generate(system="s", messages=[], tools=[])

    assert reply.text == UNCONFIGURED_MESSAGE


async def test_generate_returns_the_scripted_replies_in_order() -> None:
    first = ModelReply(
        tool_calls=(ToolCall(call_id="1", name="fake_tool", arguments={}),)
    )
    second = ModelReply(text="done")
    client = NullModelClient([first, second])

    assert await client.generate(system="s", messages=[], tools=[]) == first
    assert await client.generate(system="s", messages=[], tools=[]) == second


async def test_generate_repeats_the_last_reply_once_the_script_runs_out() -> None:
    last = ModelReply(text="only")
    client = NullModelClient([last])

    await client.generate(system="s", messages=[], tools=[])

    assert await client.generate(system="s", messages=[], tools=[]) == last


async def test_generate_records_what_it_was_sent() -> None:
    client = NullModelClient()
    message = ModelMessage(role=MessageRole.USER, text="hello")

    await client.generate(system="rules", messages=[message], tools=[SPEC])

    assert client.calls[0].system == "rules"
    assert client.calls[0].messages == (message,)
    assert client.calls[0].tools == (SPEC,)


def test_name_is_stable() -> None:
    assert NullModelClient().name == "null"
