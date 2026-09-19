"""Spec 0006 §3.4 — the Gemini wire mapping, in both directions."""

import pytest

from app.core.model import MessageRole, ModelMessage, ToolCall, ToolSpec
from app.infra.model.payload import from_response, to_request

SPEC = ToolSpec(
    name="get_holdings_summary",
    description="Return the positions.",
    parameters={"type": "object", "properties": {}},
)


def test_to_request_maps_roles_and_carries_the_system_instruction() -> None:
    body = to_request(
        system="rules",
        messages=[
            ModelMessage(role=MessageRole.USER, text="hi"),
            ModelMessage(role=MessageRole.ASSISTANT, text="hello"),
        ],
        tools=[],
    )

    assert body["systemInstruction"] == {"parts": [{"text": "rules"}]}
    assert body["contents"] == [
        {"role": "user", "parts": [{"text": "hi"}]},
        {"role": "model", "parts": [{"text": "hello"}]},
    ]
    assert "tools" not in body


def test_to_request_declares_the_offered_tools() -> None:
    body = to_request(system="s", messages=[], tools=[SPEC])

    assert body["tools"] == [
        {
            "functionDeclarations": [
                {
                    "name": SPEC.name,
                    "description": SPEC.description,
                    "parameters": dict(SPEC.parameters),
                }
            ]
        }
    ]


def test_to_request_renders_an_assistant_tool_call_as_a_function_call() -> None:
    message = ModelMessage(
        role=MessageRole.ASSISTANT,
        text="looking",
        tool_calls=(ToolCall(call_id="0-t", name="t", arguments={"top_n": 2}),),
    )

    body = to_request(system="s", messages=[message], tools=[])

    assert body["contents"] == [
        {
            "role": "model",
            "parts": [
                {"text": "looking"},
                {"functionCall": {"name": "t", "args": {"top_n": 2}}},
            ],
        }
    ]


@pytest.mark.parametrize(
    ("tool_name", "expected"),
    [("t", "t"), (None, "")],
    ids=["named_tool", "nameless_tool_result"],
)
def test_to_request_renders_a_tool_result_as_a_function_response(
    tool_name: str | None, expected: str
) -> None:
    message = ModelMessage(
        role=MessageRole.TOOL,
        tool_call_id="0-t",
        tool_name=tool_name,
        tool_result={"totalDisplay": "$1.00"},
    )

    body = to_request(system="s", messages=[message], tools=[])

    assert body["contents"] == [
        {
            "role": "function",
            "parts": [
                {
                    "functionResponse": {
                        "name": expected,
                        "response": {"totalDisplay": "$1.00"},
                    }
                }
            ],
        }
    ]


def test_to_request_drops_a_message_that_renders_to_no_part() -> None:
    body = to_request(
        system="s", messages=[ModelMessage(role=MessageRole.ASSISTANT)], tools=[]
    )

    assert body["contents"] == []


def test_from_response_reads_the_candidate_text() -> None:
    reply = from_response(
        {"candidates": [{"content": {"parts": [{"text": "answer"}]}}]}
    )

    assert reply.text == "answer"
    assert reply.tool_calls == ()


def test_from_response_reads_tool_calls_and_joins_surrounding_text() -> None:
    reply = from_response(
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {"text": "one moment"},
                            {"functionCall": {"name": "t", "args": {"top_n": 3}}},
                            {"functionCall": {"name": "u"}},
                        ]
                    }
                }
            ]
        }
    )

    assert reply.text == "one moment"
    assert [call.name for call in reply.tool_calls] == ["t", "u"]
    assert reply.tool_calls[0].arguments == {"top_n": 3}
    assert reply.tool_calls[1].arguments == {}
    assert reply.tool_calls[0].call_id == "1-t"


def test_from_response_without_candidates_raises() -> None:
    with pytest.raises(ValueError, match="no candidate"):
        from_response({"candidates": []})


def test_from_response_on_a_body_that_is_not_a_gemini_reply_raises() -> None:
    with pytest.raises(ValueError, match="candidates"):
        from_response({"candidates": "not-a-list"})
