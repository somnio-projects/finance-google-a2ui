"""Every bound the session contract promises, checked at the HTTP layer.

Spec 0004 AC-5 and AC-8: the parameters and the body are rejected before any
row is touched, so these need no database.
"""

import pytest
from fastapi.testclient import TestClient

from tests.unit.api.test_sessions_api import AUTH, SESSIONS, SOME_ID


def test_invalid_cursor_is_422_before_the_database(sessions_client: TestClient) -> None:
    """A cursor we did not issue is a validation failure, not a fresh page."""
    response = sessions_client.get(
        SESSIONS, params={"cursor": "not-a-cursor!!"}, headers=AUTH
    )
    assert response.status_code == 422
    assert response.json()["type"].endswith("/validation-failed")


@pytest.mark.parametrize(
    "params",
    [{"limit": 0}, {"limit": 101}, {"cursor": "c" * 129}],
    ids=["limit_too_small", "limit_too_large", "cursor_too_long"],
)
def test_out_of_bounds_pagination_parameters_are_422(
    sessions_client: TestClient, params: dict[str, str | int]
) -> None:
    response = sessions_client.get(SESSIONS, params=params, headers=AUTH)
    assert response.status_code == 422
    assert response.json()["type"].endswith("/malformed-request")


@pytest.mark.parametrize(
    "body",
    [
        {"role": "moderator", "content": "hi"},
        {"role": "user", "content": ""},
        {"role": "user", "content": "x" * 8_001},
        {"content": "hi"},
    ],
    ids=["unknown_role", "empty_content", "content_too_long", "missing_role"],
)
def test_invalid_message_bodies_are_422(
    sessions_client: TestClient, body: dict[str, str]
) -> None:
    response = sessions_client.post(
        f"{SESSIONS}/{SOME_ID}/messages", json=body, headers=AUTH
    )
    assert response.status_code == 422


@pytest.mark.parametrize(
    "title",
    ["", "t" * 201],
    ids=["empty_title", "title_too_long"],
)
def test_invalid_session_titles_are_422(
    sessions_client: TestClient, title: str
) -> None:
    response = sessions_client.post(SESSIONS, json={"title": title}, headers=AUTH)
    assert response.status_code == 422


def test_a_malformed_session_id_is_422(sessions_client: TestClient) -> None:
    response = sessions_client.get(f"{SESSIONS}/not-a-uuid", headers=AUTH)
    assert response.status_code == 422
