"""Spec 0010 AC-2/AC-3/AC-4 — the JSON-RPC envelope and the event stream.

Everything here is the wire contract a client SDK codes against, which is why
it is asserted at the HTTP layer rather than on the service.
"""

import json

from fastapi.testclient import TestClient

from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND, UNSUPPORTED_OPERATION

AUTH = {"Authorization": "Bearer good"}
CARD_URL = "/.well-known/agent-card.json"


def _call(method: str, **params: object) -> dict[str, object]:
    return {"jsonrpc": "2.0", "id": "req-1", "method": method, "params": params}


def _message(text: str, context_id: str | None = None) -> dict[str, object]:
    message: dict[str, object] = {
        "role": "user",
        "parts": [{"kind": "text", "text": text}],
        "messageId": "m-1",
    }
    if context_id is not None:
        message["contextId"] = context_id
    return {"message": message}


def _events(body: str) -> list[dict[str, object]]:
    """Parse a server-sent event stream into its payloads."""
    return [
        json.loads(line.removeprefix("data: "))
        for line in body.splitlines()
        if line.startswith("data: ")
    ]


def test_a_turn_without_a_token_is_refused(client: TestClient) -> None:
    """AC-4 — the protocol surface is authenticated; only the card is not."""
    response = client.post("/", json=_call("message/stream", **_message("hi")))

    assert response.status_code == 401
    assert response.json()["type"].endswith("auth/missing-token")


def test_a_turn_streams_a_working_status_then_the_answer(client: TestClient) -> None:
    """AC-2 — the event order a client SDK depends on."""
    response = client.post(
        "/", json=_call("message/stream", **_message("what do I hold?")), headers=AUTH
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = _events(response.text)
    assert [event["kind"] for event in events] == [
        "status-update",
        "message",
        "status-update",
    ]
    assert events[0]["status"] == {"state": "working"}
    assert events[0]["final"] is False
    assert events[-1]["final"] is True


def test_the_context_id_is_echoed_for_correlation(client: TestClient) -> None:
    """It is echoed, never trusted: history is GGU-46 (spec 0010 OD-2)."""
    response = client.post(
        "/",
        json=_call("message/stream", **_message("hello", context_id="ctx-42")),
        headers=AUTH,
    )

    assert {event["contextId"] for event in _events(response.text)} == {"ctx-42"}


def test_an_unknown_method_is_a_json_rpc_error_not_an_http_error(
    client: TestClient,
) -> None:
    """AC-3 — JSON-RPC reports faults in the body, at HTTP 200."""
    response = client.post("/", json=_call("tasks/resubscribe"), headers=AUTH)

    assert response.status_code == 200
    body = response.json()
    assert body["error"]["code"] == METHOD_NOT_FOUND
    assert body["id"] == "req-1"


def test_cancel_is_refused_in_the_documented_way(client: TestClient) -> None:
    """ADR-D D-9 — the client calls it on every cancellation; a 500 was worse."""
    response = client.post("/", json=_call("tasks/cancel"), headers=AUTH)

    assert response.status_code == 200
    assert response.json()["error"]["code"] == UNSUPPORTED_OPERATION


def test_parameters_the_method_does_not_accept_are_refused(
    client: TestClient,
) -> None:
    response = client.post("/", json=_call("message/stream"), headers=AUTH)

    assert response.json()["error"]["code"] == INVALID_PARAMS


def test_a_body_that_is_not_json_rpc_is_refused(client: TestClient) -> None:
    response = client.post("/", json={"not": "an envelope"}, headers=AUTH)

    assert response.json()["error"]["code"] == INVALID_PARAMS


def test_a_body_that_is_not_json_at_all_is_refused(client: TestClient) -> None:
    response = client.post(
        "/", content=b"<xml/>", headers={**AUTH, "Content-Type": "application/json"}
    )

    assert response.json()["error"]["code"] == INVALID_PARAMS


def test_no_error_body_carries_internal_text(client: TestClient) -> None:
    """A protocol error is still an information-disclosure surface."""
    for method in ("tasks/cancel", "tasks/resubscribe"):
        body = client.post("/", json=_call(method), headers=AUTH).json()
        message = body["error"]["message"]
        assert "Traceback" not in message
        assert "app." not in message
