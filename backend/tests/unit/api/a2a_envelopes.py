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


def events(body: str) -> list[dict[str, object]]:
    """Parse a server-sent event stream into its payloads."""
    return [
        json.loads(line.removeprefix("data: "))
        for line in body.splitlines()
        if line.startswith("data: ")
    ]


__all__ = ["AUTH", "CARD_URL", "call", "events", "message"]
