"""The conversation sub-resource against a real PostgreSQL (spec 0004 AC-5/6)."""

from fastapi.testclient import TestClient

from tests.integration.conftest import SESSIONS, open_session, subject_headers


def test_messages_round_trip_oldest_first(integration_client: TestClient) -> None:
    """Spec 0004 AC-5, AC-6: append turns, read them back newest-last, audited."""
    headers = subject_headers()
    session_id = open_session(integration_client, headers)
    for role, content in (("user", "how did I do?"), ("assistant", "4.2 % up")):
        appended = integration_client.post(
            f"{SESSIONS}/{session_id}/messages",
            json={"role": role, "content": content},
            headers=headers,
        )
        assert appended.status_code == 201, appended.text
        assert appended.json()["session_id"] == session_id

    conversation = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", headers=headers
    ).json()
    assert [m["content"] for m in conversation["items"]] == [
        "how did I do?",
        "4.2 % up",
    ]
    assert conversation["next_cursor"] is None

    audit = integration_client.get("/v1/me/audit-events", headers=headers).json()
    assert ("session.append", session_id) in [
        (event["action"], event["target"]) for event in audit
    ]


def test_message_listing_pages_oldest_first(integration_client: TestClient) -> None:
    """Spec 0004 AC-6: the cursor walks the conversation forward in order."""
    headers = subject_headers()
    session_id = open_session(integration_client, headers)
    for turn in ("first", "second", "third"):
        integration_client.post(
            f"{SESSIONS}/{session_id}/messages",
            json={"role": "user", "content": turn},
            headers=headers,
        )

    page = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", params={"limit": 2}, headers=headers
    ).json()
    assert [m["content"] for m in page["items"]] == ["first", "second"]
    assert page["next_cursor"]

    tail = integration_client.get(
        f"{SESSIONS}/{session_id}/messages",
        params={"limit": 2, "cursor": page["next_cursor"]},
        headers=headers,
    ).json()
    assert [m["content"] for m in tail["items"]] == ["third"]
    assert tail["next_cursor"] is None


def test_invalid_message_is_422(integration_client: TestClient) -> None:
    """Spec 0004 AC-5: the role is constrained before the row is ever written."""
    headers = subject_headers()
    session_id = open_session(integration_client, headers)
    response = integration_client.post(
        f"{SESSIONS}/{session_id}/messages",
        json={"role": "moderator", "content": "hi"},
        headers=headers,
    )
    assert response.status_code == 422
    conversation = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", headers=headers
    ).json()
    assert conversation["items"] == []
