"""Spec 0006 §3.4 — reading a Gemini reply, and GGU-88's round trip.

The round-trip test is the one that bites. Reading a ``thoughtSignature`` and
echoing it are two halves of one fact, and each half passes its own test while
the turn still dies: the signature has to leave in the same shape it arrived.
"""

from app.core.model import MessageRole, ModelMessage
from app.infra.model.payload import to_request
from app.infra.model.reply import THOUGHT_SIGNATURE, from_response

# Opaque by contract; the real one is ~572 characters of base64.
SIGNATURE = "Ct8BAdHtim9sTzJ1bm5pbmcgdGhlIHRvb2w"


def call_body(signature: str | None = SIGNATURE) -> dict[str, object]:
    """Build a one-call reply body, with or without a signature."""
    part: dict[str, object] = {"functionCall": {"name": "t", "args": {"top_n": 3}}}
    if signature is not None:
        part[THOUGHT_SIGNATURE] = signature
    return {"candidates": [{"content": {"parts": [part]}}]}


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


def test_from_response_keeps_the_thought_signature_gemini_3_sends() -> None:
    reply = from_response(call_body())

    assert reply.tool_calls[0].provider_state == {THOUGHT_SIGNATURE: SIGNATURE}


def test_from_response_carries_no_provider_state_when_none_was_sent() -> None:
    reply = from_response(call_body(signature=None))

    assert reply.tool_calls[0].provider_state == {}


def test_a_tool_call_keeps_its_signature_across_the_whole_round_trip() -> None:
    """GGU-88 in one assertion: what arrived beside the call goes back beside it.

    Dropping the signature is a 400 on the *second* model call — after the
    tool has already run and its surface has already been streamed — so the
    two halves have to be asserted together or neither notices.
    """
    reply = from_response(call_body())

    body = to_request(
        system="s",
        messages=[
            ModelMessage(role=MessageRole.ASSISTANT, tool_calls=reply.tool_calls)
        ],
        tools=[],
    )

    contents = body["contents"]
    assert contents == [
        {
            "role": "model",
            "parts": [
                {
                    THOUGHT_SIGNATURE: SIGNATURE,
                    "functionCall": {"name": "t", "args": {"top_n": 3}},
                }
            ],
        }
    ]


def test_provider_state_can_never_displace_the_call_it_travels_with() -> None:
    reply = from_response(call_body())
    hostile = reply.tool_calls[0].model_copy(
        update={"provider_state": {"functionCall": "hijacked"}}
    )

    body = to_request(
        system="s",
        messages=[ModelMessage(role=MessageRole.ASSISTANT, tool_calls=(hostile,))],
        tools=[],
    )

    contents = body["contents"]
    assert isinstance(contents, list)
    part = contents[0]["parts"][0]
    assert part["functionCall"] == {"name": "t", "args": {"top_n": 3}}
