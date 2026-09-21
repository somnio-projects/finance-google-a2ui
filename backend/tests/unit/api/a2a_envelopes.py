"""Envelope builders shared by the A2A HTTP suites.

One copy, because the refusal tests and the happy-path tests send the same
shapes and pylint's duplicate-code check is right to refuse two.
"""

import json

AUTH = {"Authorization": "Bearer good"}
CARD_URL = "/.well-known/agent-card.json"


def call(method: str, **params: object) -> dict[str, object]:
    """Build a JSON-RPC request envelope for ``method``."""
    return {"jsonrpc": "2.0", "id": "req-1", "method": method, "params": params}


def message(text: str, context_id: str | None = None) -> dict[str, object]:
    """Build the ``params`` of a ``message/stream`` call."""
    body: dict[str, object] = {
        "role": "user",
        "parts": [{"kind": "text", "text": text}],
        "messageId": "m-1",
    }
    if context_id is not None:
        body["contextId"] = context_id
    return {"message": body}


def action_message(
    action: str, args: dict[str, object] | None = None, *, text: str | None = None
) -> dict[str, object]:
    """Build the ``params`` of a `message/stream` carrying a `data` part.

    Args:
        action: The action id the surface sends back.
        args: Its scalar arguments, or ``None`` for the action's defaults.
        text: A text part to send *alongside* the action — which the envelope
            refuses (spec 0022 AC-5), so only a rejection test passes it.

    Returns:
        The ``params`` object of the call.
    """
    parts: list[dict[str, object]] = [
        {"kind": "data", "data": {"action": action, "args": args or {}}}
    ]
    if text is not None:
        parts.append({"kind": "text", "text": text})
    return {"message": {"role": "user", "parts": parts, "messageId": "m-1"}}


def events(body: str) -> list[dict[str, object]]:
    """Parse a server-sent event stream into its payloads."""
    return [
        json.loads(line.removeprefix("data: "))
        for line in body.splitlines()
        if line.startswith("data: ")
    ]


__all__ = ["AUTH", "CARD_URL", "action_message", "call", "events", "message"]
