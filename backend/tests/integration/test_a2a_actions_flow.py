"""AC-3, AC-4, AC-10, AC-13 — a surface action through the whole stack.

The unit suite fakes the flag service and the audit trail; this one uses the
real ones against PostgreSQL, because the facts worth proving end to end are
the ones a fake cannot prove: that the flag is read from the real store, and
that a tap writes **no** row into `audit_events` — the trail
`/v1/me/audit-events` exists to show, which taps would bury (OD-4).

**Every test here sets the flag state it needs and puts it back.** The first
draft did not: it asserted the refusal *before* any test enabled the flag, so
it passed once against a virgin database and failed on the second run of the
same file — the flag row it had just written was still there. A test that
only passes on an empty table is green on CI and red for the next developer,
which is worth less than no test. Where the **default** is off is asserted in
`tests/unit/services/test_surface_action_service.py`, because that is a
property of the call the service makes, not of a stored row.
"""

import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND
from app.services.a2a_actions import ACTIONS_DISABLED, UNKNOWN_ACTION
from app.services.surface_action_service import FEATURE_KEY
from tests.conftest import make_token

DRILL = "drill.attribution.v1"
FLAGS = "/v1/admin/feature-flags"
AUDIT = "/v1/me/audit-events"


def _headers(subject: str | None = None) -> dict[str, str]:
    token = make_token(subject=subject or f"user-{uuid.uuid4()}", ttl_seconds=10**9)
    return {"Authorization": f"Bearer {token}"}


def _admin_headers() -> dict[str, str]:
    token = make_token(
        subject=f"admin-{uuid.uuid4()}", ttl_seconds=10**9, extra={"roles": ["admin"]}
    )
    return {"Authorization": f"Bearer {token}"}


def _set_flag(client: TestClient, *, enabled: bool) -> None:
    """Put `surface.actions` into a known state through the admin API."""
    response = client.put(
        f"{FLAGS}/{FEATURE_KEY}",
        json={"enabled": enabled, "description": "GGU-78 integration test"},
        headers=_admin_headers(),
    )
    assert response.status_code == 200, response.text
    assert response.json()["enabled"] is enabled


@pytest.fixture
def actions_enabled(integration_client: TestClient) -> Iterator[TestClient]:
    """Turn the capability on for one test, then put it back off.

    Restoring matters twice over: the next test in this file must not inherit
    it, and neither must the next *run* against the same database.
    """
    _set_flag(integration_client, enabled=True)
    yield integration_client
    _set_flag(integration_client, enabled=False)


@pytest.fixture
def actions_disabled(integration_client: TestClient) -> Iterator[TestClient]:
    """Pin the capability off, whatever the database happened to hold."""
    _set_flag(integration_client, enabled=False)
    yield integration_client


def _action_call(action: str = DRILL, **args: object) -> dict[str, object]:
    """Build a `message/stream` envelope carrying one `data` part."""
    return {
        "jsonrpc": "2.0",
        "id": "req-1",
        "method": "message/stream",
        "params": {
            "message": {
                "role": "user",
                "parts": [
                    {
                        "kind": "data",
                        "data": {"action": action, "args": args or {"driver": "DOGE"}},
                    }
                ],
                "messageId": "m-1",
            }
        },
    }


def test_an_action_is_method_not_found_while_the_capability_is_off(
    actions_disabled: TestClient,
) -> None:
    """AC-13 — a disabled capability is one that does not exist."""
    response = actions_disabled.post("/", json=_action_call(), headers=_headers())

    assert response.status_code == 200
    assert response.json()["error"] == {
        "code": METHOD_NOT_FOUND,
        "message": ACTIONS_DISABLED,
    }


def test_a_data_part_runs_a_turn_and_streams_surfaces(
    actions_enabled: TestClient,
) -> None:
    """AC-3 — once enabled, an action is an ordinary streamed turn."""
    response = actions_enabled.post("/", json=_action_call(), headers=_headers())

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    assert "status-update" in response.text


def test_an_unknown_action_is_a_json_rpc_error_at_http_200(
    actions_enabled: TestClient,
) -> None:
    """AC-4 — rejection is terminal: no stream, no fallback turn."""
    response = actions_enabled.post(
        "/", json=_action_call("no.such.v1"), headers=_headers()
    )

    assert response.status_code == 200
    assert response.json()["error"] == {
        "code": INVALID_PARAMS,
        "message": UNKNOWN_ACTION,
    }


def test_a_tap_leaves_no_audit_event(actions_enabled: TestClient) -> None:
    """AC-10 — neither shipped action decides anything, so none is recorded.

    Scoped to a fresh subject, so the assertion is about *this* tap rather
    than about the table being empty.
    """
    headers = _headers(f"user-{uuid.uuid4()}")

    actions_enabled.post("/", json=_action_call(), headers=headers)
    after = actions_enabled.get(AUDIT, headers=headers)

    assert after.status_code == 200
    recorded = [row["action"] for row in after.json()]
    assert [name for name in recorded if "surface_action" in name] == []
