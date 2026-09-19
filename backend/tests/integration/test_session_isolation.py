"""The property GGU-46 exists for: subject A's session is invisible to B.

ADR-A D-6 and spec 0004 §5. Token verification and isolation are independent
properties, so this file never assumes that a verified token implies an
authorised one: it drives two *verified* subjects against the same session id
and asserts that the second one is answered exactly as if the session did not
exist — and that nothing it does reaches the first one's data.

Mutation check for these tests: comment the ``subject`` filter out of
``SessionRepository.get_for_subject`` (and ``delete_for_subject``) and every
test below must go red.
"""

import uuid

from fastapi.testclient import TestClient

from tests.integration.conftest import SESSIONS, open_session, subject_headers

MISSING = "https://errors.finance-a2ui/not-found"


def _two_subjects() -> tuple[dict[str, str], dict[str, str]]:
    """Two independently verified subjects from the same test run."""
    run = uuid.uuid4()
    return subject_headers(f"owner-{run}"), subject_headers(f"intruder-{run}")


def test_other_subject_gets_404_on_read(integration_client: TestClient) -> None:
    owner, intruder = _two_subjects()
    session_id = open_session(integration_client, owner, "private")

    denied = integration_client.get(f"{SESSIONS}/{session_id}", headers=intruder)
    assert denied.status_code == 404
    assert denied.json()["type"] == MISSING

    # Indistinguishable from an id that never existed: same type, title and
    # status, and a detail that differs only by the id the caller itself sent.
    absent = uuid.uuid4()
    unknown = integration_client.get(f"{SESSIONS}/{absent}", headers=intruder)
    assert unknown.status_code == denied.status_code
    assert denied.json()["detail"] == f"session {session_id} not found"
    assert unknown.json()["detail"] == f"session {absent} not found"
    assert {k: v for k, v in denied.json().items() if k in {"type", "title"}} == {
        k: v for k, v in unknown.json().items() if k in {"type", "title"}
    }


def test_other_subject_gets_404_on_delete_and_leaves_the_session_intact(
    integration_client: TestClient,
) -> None:
    owner, intruder = _two_subjects()
    session_id = open_session(integration_client, owner, "private")

    denied = integration_client.delete(f"{SESSIONS}/{session_id}", headers=intruder)
    assert denied.status_code == 404
    assert denied.json()["type"] == MISSING

    still_there = integration_client.get(f"{SESSIONS}/{session_id}", headers=owner)
    assert still_there.status_code == 200
    assert still_there.json()["id"] == session_id


def test_other_subject_gets_404_on_message_append(
    integration_client: TestClient,
) -> None:
    owner, intruder = _two_subjects()
    session_id = open_session(integration_client, owner, "private")

    denied = integration_client.post(
        f"{SESSIONS}/{session_id}/messages",
        json={"role": "user", "content": "let me in"},
        headers=intruder,
    )
    assert denied.status_code == 404
    assert denied.json()["type"] == MISSING

    conversation = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", headers=owner
    )
    assert conversation.status_code == 200
    assert conversation.json()["items"] == []


def test_other_subject_gets_404_on_reading_the_conversation(
    integration_client: TestClient,
) -> None:
    owner, intruder = _two_subjects()
    session_id = open_session(integration_client, owner, "private")
    integration_client.post(
        f"{SESSIONS}/{session_id}/messages",
        json={"role": "user", "content": "my portfolio"},
        headers=owner,
    )

    denied = integration_client.get(
        f"{SESSIONS}/{session_id}/messages", headers=intruder
    )
    assert denied.status_code == 404
    assert "my portfolio" not in denied.text


def test_listing_never_shows_another_subjects_session(
    integration_client: TestClient,
) -> None:
    owner, intruder = _two_subjects()
    session_id = open_session(integration_client, owner, "private")

    listed = integration_client.get(
        SESSIONS, params={"limit": 100}, headers=intruder
    ).json()
    assert session_id not in [item["id"] for item in listed["items"]]
