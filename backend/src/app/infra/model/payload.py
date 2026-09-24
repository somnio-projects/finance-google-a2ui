"""The shape of Gemini's ``generateContent`` request (spec 0006 §3.4).

It delegates two things: a tool's ``parameters`` belong to ``tool_schema.py``,
and the roles this file may emit are the measured set in ``wire_roles.py``.
Reading the provider's answer is ``reply.py``'s job.

Mapping lives apart from transport for the same reason ``jwks.py`` lives apart
from ``oidc_provider.py``: the shape of a provider's JSON and the handling of
its failures are different problems, and each is easier to test alone.

**A tool result travels under role ``"user"``** (GGU-90). Gemini has no tool
role: the ``functionResponse`` *part* is what marks it as a tool result, and
the only role the API accepts for it is ``"user"``. Sending ``"function"``,
which is what this file did until GGU-90, is a 400 on every turn that calls a
tool — see ``wire_roles.py`` for the provider's own list.
"""

from collections.abc import Mapping, Sequence

from app.core.model import MessageRole, ModelMessage, ToolSpec
from app.infra.model.tool_schema import to_gemini_schema

#: How our roles cross the wire. Public because it is a *checked* artefact:
#: ``tests/unit/infra/model/test_wire_roles.py`` compares every value here
#: against the set the provider itself printed (``wire_roles.py``).
ROLES: Mapping[MessageRole, str] = {
    MessageRole.USER: "user",
    MessageRole.ASSISTANT: "model",
    # Not "function": the API refuses it outright, and a functionResponse
    # part is already what distinguishes a tool result from a question.
    MessageRole.TOOL: "user",
}


def _call_part(
    name: str, args: Mapping[str, object], state: Mapping[str, object]
) -> dict[str, object]:
    """Render one tool call, carrying back whatever the provider attached.

    Args:
        name: The tool the model asked for.
        args: The arguments it supplied.
        state: Opaque provider state from the reply that produced this call —
            Gemini 3's ``thoughtSignature`` (GGU-88).

    Returns:
        The ``functionCall`` part. The state is splatted in **first** so a
        provider key can never displace the call itself.
    """
    return {**state, "functionCall": {"name": name, "args": dict(args)}}


def _message_parts(message: ModelMessage) -> list[dict[str, object]]:
    """Render one of our messages as Gemini parts."""
    if message.tool_result is not None:
        response = {"name": message.tool_name or "", "response": message.tool_result}
        return [{"functionResponse": response}]
    parts: list[dict[str, object]] = []
    if message.text:
        parts.append({"text": message.text})
    parts.extend(
        _call_part(call.name, call.arguments, call.provider_state)
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
        {"role": ROLES[message.role], "parts": parts}
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


__all__ = ["ROLES", "to_request"]
