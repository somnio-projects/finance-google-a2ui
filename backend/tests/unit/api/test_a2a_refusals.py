"""Spec 0010 AC-3 — every envelope this surface refuses, and how.

A protocol fault is a JSON-RPC error object at HTTP 200, never a transport
error: the client SDK reads the body, not the status. Split from the happy
path so both stay inside the line budget.
"""

from fastapi.testclient import TestClient

from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND, UNSUPPORTED_OPERATION
from tests.unit.api.a2a_envelopes import AUTH, call, message


def test_an_unknown_method_is_a_json_rpc_error_not_an_http_error(
    client: TestClient,
) -> None:
    """AC-3 — JSON-RPC reports faults in the body, at HTTP 200."""
    response = client.post("/", json=call("tasks/resubscribe"), headers=AUTH)

    assert response.status_code == 200
    body = response.json()
    assert body["error"]["code"] == METHOD_NOT_FOUND
    assert body["id"] == "req-1"


def test_cancel_is_refused_in_the_documented_way(client: TestClient) -> None:
    """ADR-D D-9 — the client calls it on every cancellation; a 500 was worse."""
    response = client.post("/", json=call("tasks/cancel"), headers=AUTH)

    assert response.status_code == 200
    assert response.json()["error"]["code"] == UNSUPPORTED_OPERATION


def test_parameters_the_method_does_not_accept_are_refused(
    client: TestClient,
) -> None:
    response = client.post("/", json=call("message/stream"), headers=AUTH)

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
        body = client.post("/", json=call(method), headers=AUTH).json()
        message = body["error"]["message"]
        assert "Traceback" not in message
        assert "app." not in message


def test_a_hostile_method_name_is_still_a_json_rpc_error(
    unlimited_client: TestClient,
) -> None:
    """The regression that answered 500.

    `method` is bounded at 64 characters, but `repr()` of 64 control
    characters is far longer — so interpolating it into an error message
    whose field is bounded at 256 raised a ValidationError inside the helper
    that exists to avoid a transport error. Messages are fixed strings now.
    """
    hostile = "\x01" * 64

    response = unlimited_client.post("/", json=call(hostile), headers=AUTH)

    assert response.status_code == 200
    assert response.json()["error"]["code"] == METHOD_NOT_FOUND


def test_an_oversized_correlation_id_is_refused_not_reflected(
    unlimited_client: TestClient,
) -> None:
    """An unbounded id is an unbounded response, since it is echoed verbatim.

    Sized under the body limit on purpose: a bigger payload is caught by the
    413 first, which would prove the limiter rather than this bound.
    """
    envelope = call("message/stream", **message("hi"))
    envelope["id"] = "x" * 500

    body = unlimited_client.post("/", json=envelope, headers=AUTH).json()

    assert body["error"]["code"] == INVALID_PARAMS
    assert body["id"] is None


def test_an_unbounded_parameter_map_is_refused(unlimited_client: TestClient) -> None:
    envelope = call("message/stream")
    envelope["params"] = {f"k{index}": index for index in range(100)}

    assert unlimited_client.post("/", json=envelope, headers=AUTH).json()["error"][
        "code"
    ] == (INVALID_PARAMS)
