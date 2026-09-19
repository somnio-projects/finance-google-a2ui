"""Sessions themselves, against a real PostgreSQL (spec 0004 AC-1..AC-4, AC-7)."""

from datetime import datetime

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.bootstrap import build_container, create_app
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings
from tests.integration.conftest import SESSIONS, open_session, subject_headers


def test_create_returns_location_and_round_trips(
    integration_client: TestClient,
) -> None:
    """Spec 0004 AC-1, AC-3: create, Location, read back, audit trail."""
    headers = subject_headers()
    created = integration_client.post(
        SESSIONS, json={"title": "Retirement review"}, headers=headers
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert created.headers["Location"] == f"{SESSIONS}/{body['id']}"
    assert body["title"] == "Retirement review"
    assert "subject" not in body

    read = integration_client.get(f"{SESSIONS}/{body['id']}", headers=headers)
    assert read.status_code == 200
    assert read.json()["id"] == body["id"]

    audit = integration_client.get("/v1/me/audit-events", headers=headers).json()
    recorded = [(event["action"], event["target"]) for event in audit]
    assert ("session.create", body["id"]) in recorded
    assert ("session.read", body["id"]) in recorded


def test_session_listing_pages_newest_first(integration_client: TestClient) -> None:
    """Spec 0004 AC-2: only my sessions, newest first, cursor never repeats a row."""
    headers = subject_headers()
    opened = [open_session(integration_client, headers, str(n)) for n in range(3)]

    first = integration_client.get(SESSIONS, params={"limit": 2}, headers=headers)
    assert first.status_code == 200
    page = first.json()
    assert [item["id"] for item in page["items"]] == list(reversed(opened))[:2]
    assert page["next_cursor"]

    second = integration_client.get(
        SESSIONS, params={"limit": 2, "cursor": page["next_cursor"]}, headers=headers
    )
    tail = second.json()
    assert [item["id"] for item in tail["items"]] == [opened[0]]
    assert tail["next_cursor"] is None


def test_delete_is_204_then_404_and_cascades_messages(
    integration_client: TestClient,
) -> None:
    """Spec 0004 AC-4: 204, the messages go with it, repeating is a 404."""
    headers = subject_headers()
    session_id = open_session(integration_client, headers)
    integration_client.post(
        f"{SESSIONS}/{session_id}/messages",
        json={"role": "user", "content": "delete me"},
        headers=headers,
    )

    removed = integration_client.delete(f"{SESSIONS}/{session_id}", headers=headers)
    assert removed.status_code == 204
    assert removed.content == b""
    gone = integration_client.get(f"{SESSIONS}/{session_id}", headers=headers)
    assert gone.status_code == 404
    again = integration_client.delete(f"{SESSIONS}/{session_id}", headers=headers)
    assert again.status_code == 404
    conversation = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", headers=headers
    )
    assert conversation.status_code == 404


def test_appending_bumps_the_session_updated_at(
    integration_client: TestClient,
) -> None:
    """Spec 0004 §4: ``updated_at`` is last activity, not creation time."""
    headers = subject_headers()
    session_id = open_session(integration_client, headers)
    before = integration_client.get(f"{SESSIONS}/{session_id}", headers=headers).json()
    integration_client.post(
        f"{SESSIONS}/{session_id}/messages",
        json={"role": "user", "content": "ping"},
        headers=headers,
    )
    after = integration_client.get(f"{SESSIONS}/{session_id}", headers=headers).json()
    assert datetime.fromisoformat(after["updated_at"]) > datetime.fromisoformat(
        before["updated_at"]
    )
    assert after["created_at"] == before["created_at"]


def test_invalid_cursor_is_422(integration_client: TestClient) -> None:
    """Spec 0004 AC-8: a cursor we did not issue is rejected, not ignored."""
    response = integration_client.get(
        SESSIONS,
        params={"cursor": "definitely-not-a-cursor"},
        headers=subject_headers(),
    )
    assert response.status_code == 422
    assert response.json()["type"].endswith("/validation-failed")


def test_flag_off_hides_every_session_route(
    database_url: str, integration_reporter: FakeReporter
) -> None:
    """Spec 0004 AC-7: the kill-switch takes the whole surface down."""
    settings = make_settings(
        database_url=database_url,
        trusted_hosts=["*"],
        feature_flags_force_disabled=["sessions.api"],
    )
    app: FastAPI = create_app(
        settings,
        container=build_container(
            settings, clock=FixedClock(FROZEN_NOW), reporter=integration_reporter
        ),
    )
    with TestClient(app) as client:
        headers = subject_headers()
        created = client.post(SESSIONS, json={"title": "x"}, headers=headers)
        assert created.status_code == 404
        assert created.json()["type"].endswith("/feature-disabled")
        assert client.get(SESSIONS, headers=headers).status_code == 404
