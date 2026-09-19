"""Spec 0010 AC-2/AC-3/AC-4 — the JSON-RPC envelope and the event stream.

Everything here is the wire contract a client SDK codes against, which is why
it is asserted at the HTTP layer rather than on the service.
"""

from fastapi.testclient import TestClient

from tests.unit.api.a2a_envelopes import AUTH, call, events, message


def test_a_turn_without_a_token_is_refused(client: TestClient) -> None:
    """AC-4 — the protocol surface is authenticated; only the card is not."""
    response = client.post("/", json=call("message/stream", **message("hi")))

    assert response.status_code == 401
    assert response.json()["type"].endswith("auth/missing-token")


def test_a_turn_streams_a_working_status_then_the_answer(client: TestClient) -> None:
    """AC-2 — the event order a client SDK depends on."""
    response = client.post(
        "/", json=call("message/stream", **message("what do I hold?")), headers=AUTH
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    stream = events(response.text)
    assert [event["kind"] for event in stream] == [
        "status-update",
        "message",
        "status-update",
    ]
    assert stream[0]["status"] == {"state": "working"}
    assert stream[0]["final"] is False
    assert stream[-1]["final"] is True


def test_the_context_id_is_echoed_for_correlation(client: TestClient) -> None:
    """It is echoed, never trusted: history is GGU-46 (spec 0010 OD-2)."""
    response = client.post(
        "/",
        json=call("message/stream", **message("hello", context_id="ctx-42")),
        headers=AUTH,
    )

    assert {event["contextId"] for event in events(response.text)} == {"ctx-42"}
