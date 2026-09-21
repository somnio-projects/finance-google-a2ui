"""The shape of Gemini's ``generateContent`` request and response.

It delegates one thing: a tool's ``parameters`` belong to ``tool_schema.py``.

Mapping lives apart from transport for the same reason ``jwks.py`` lives apart
from ``oidc_provider.py``: the shape of a provider's JSON and the handling of
its failures are different problems, and each is easier to test alone. The
response is parsed into pydantic models before anything reads it, so a body
that is merely *JSON* but not a Gemini reply fails here, loudly and early.
"""

from collections.abc import Mapping, Sequence
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.core.model import MessageRole, ModelMessage, ModelReply, ToolCall, ToolSpec
from app.infra.model.tool_schema import to_gemini_schema

_ROLES: Mapping[MessageRole, str] = {
    MessageRole.USER: "user",
    MessageRole.ASSISTANT: "model",
    MessageRole.TOOL: "function",
}


class _FunctionCall(BaseModel):
    """A ``functionCall`` part of a Gemini candidate."""

    model_config = ConfigDict(populate_by_name=True)

    name: str = Field(min_length=1)
    args: dict[str, Any] = Field(default_factory=dict)


class _Part(BaseModel):
    """One part of a candidate's content: prose, a call, or both."""

    model_config = ConfigDict(populate_by_name=True)

    text: str | None = None
    function_call: _FunctionCall | None = Field(default=None, alias="functionCall")


class _Content(BaseModel):
    """The content block of a candidate."""

    parts: list[_Part] = Field(default_factory=list)


class _Candidate(BaseModel):
    """One candidate answer."""

    content: _Content = Field(default_factory=_Content)


class GeminiResponse(BaseModel):
    """The subset of ``generateContent``'s response this adapter reads."""

    candidates: list[_Candidate] = Field(default_factory=list)


def _message_parts(message: ModelMessage) -> list[dict[str, object]]:
    """Render one of our messages as Gemini parts."""
    if message.tool_result is not None:
        response = {"name": message.tool_name or "", "response": message.tool_result}
        return [{"functionResponse": response}]
    parts: list[dict[str, object]] = []
    if message.text:
        parts.append({"text": message.text})
    parts.extend(
        {"functionCall": {"name": call.name, "args": dict(call.arguments)}}
        for call in message.tool_calls
    )
    return parts


def to_request(
    *, system: str, messages: Sequence[ModelMessage], tools: Sequence[ToolSpec]
) -> dict[str, object]:
    """Build the ``generateContent`` request body.

    Args:
        system: The system instruction for this turn.
        messages: The whole conversation, oldest first.
        tools: The tools the model may call.

    Returns:
        A JSON-serialisable body. Messages that render to no part are dropped
        (Gemini rejects an empty ``parts`` array), and each tool's schema
        crosses through ``to_gemini_schema`` — GGU-81.
    """
    contents = [
        {"role": _ROLES[message.role], "parts": parts}
        for message in messages
        if (parts := _message_parts(message))
    ]
    body: dict[str, object] = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": contents,
    }
    if tools:
        body["tools"] = [
            {
                "functionDeclarations": [
                    {
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": to_gemini_schema(tool.parameters),
                    }
                    for tool in tools
                ]
            }
        ]
    return body


def from_response(payload: object) -> ModelReply:
    """Parse a ``generateContent`` response into a ``ModelReply``.

    Args:
        payload: The decoded JSON body.

    Returns:
        The assistant's text and the tool calls it asked for.

    Raises:
        ValueError: When the body is not a Gemini reply, or carries no
            candidate. ``pydantic.ValidationError`` is a ``ValueError``, so one
            ``except`` in the client covers both.
    """
    parsed = GeminiResponse.model_validate(payload)
    if not parsed.candidates:
        msg = "response carried no candidate"
        raise ValueError(msg)
    parts = parsed.candidates[0].content.parts
    text = "".join(part.text for part in parts if part.text)
    calls = tuple(
        ToolCall(
            call_id=f"{index}-{part.function_call.name}",
            name=part.function_call.name,
            arguments=part.function_call.args,
        )
        for index, part in enumerate(parts)
        if part.function_call is not None
    )
    return ModelReply(text=text, tool_calls=calls)


__all__ = ["GeminiResponse", "from_response", "to_request"]
