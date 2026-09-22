"""Admin account routes at the HTTP layer, the service faked (spec 0027)."""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_user_service
from app.core.errors import AuthorizationError, NotFoundError
from app.core.principal import Principal
from app.schemas.users import UserInvite, UserResponse, UserStatus
from tests.conftest import FROZEN_NOW

USERS = "/v1/admin/users"
AUTH = {"Authorization": "Bearer good"}


def _row(email: str, status: UserStatus = "invited") -> UserResponse:
    return UserResponse(
        email=email,
        role="member",
        status=status,
        invited_by="root@somnio.dev",
        created_at=FROZEN_NOW,
    )  # pyright: ignore[reportArgumentType]


class FakeUsers:
    """Service double: answers like the real one without a database."""

    def __init__(self, *, forbidden: bool = False) -> None:
        self.forbidden = forbidden
        self.calls: list[tuple[str, object]] = []

    def _gate(self) -> None:
        if self.forbidden:
            raise AuthorizationError("managing accounts requires the admin scope")

    async def list_users(
        self, principal: Principal, *, limit: int, request_id: str
    ) -> list[UserResponse]:
        self._gate()
        self.calls.append(("list", limit))
        return [_row("a@example.test")]

    async def invite(
        self, principal: Principal, body: UserInvite, *, request_id: str
    ) -> UserResponse:
        self._gate()
        self.calls.append(("invite", body))
        return _row(body.email)

    async def set_status(
        self, principal: Principal, *, email: str, status: str, request_id: str
    ) -> UserResponse:
        self._gate()
        if email.startswith("missing"):
            raise NotFoundError(f"no account for {email}")
        self.calls.append(("status", (email, status)))
        return _row(email, status)  # pyright: ignore[reportArgumentType]


@pytest.fixture
def users() -> FakeUsers:
    return FakeUsers()


@pytest.fixture
def users_client(app: FastAPI, users: FakeUsers) -> Iterator[TestClient]:
    app.dependency_overrides[get_user_service] = lambda: users
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


def test_every_admin_route_needs_a_token(users_client: TestClient) -> None:
    assert users_client.get(USERS).status_code == 401
    assert users_client.post(USERS, json={"email": "a@b.test"}).status_code == 401
    assert (
        users_client.patch(f"{USERS}/a@b.test", json={"status": "active"}).status_code
        == 401
    )


def test_list_passes_the_bounded_limit(
    users_client: TestClient, users: FakeUsers
) -> None:
    response = users_client.get(USERS, headers=AUTH, params={"limit": 5})
    assert response.status_code == 200
    assert response.json()[0]["email"] == "a@example.test"
    assert users.calls == [("list", 5)]
    assert users_client.get(USERS, headers=AUTH, params={"limit": 0}).status_code == 422


def test_invite_answers_201_with_a_location(
    users_client: TestClient, users: FakeUsers
) -> None:
    response = users_client.post(
        USERS, headers=AUTH, json={"email": " New@Example.test ", "display_name": "New"}
    )
    assert response.status_code == 201
    assert response.headers["Location"] == f"{USERS}/new@example.test"
    assert response.json()["email"] == "new@example.test"
    body = users.calls[0][1]
    assert isinstance(body, UserInvite) and body.email == "new@example.test"


@pytest.mark.parametrize(
    "payload",
    [{"email": "not-an-email"}, {"email": "a@b.test", "role": "owner"}, {}],
    ids=["bad-email", "bad-role", "empty"],
)
def test_invite_rejects_what_the_schema_does_not_declare(
    users_client: TestClient, payload: dict[str, str]
) -> None:
    assert users_client.post(USERS, headers=AUTH, json=payload).status_code == 422


def test_status_change_lower_cases_the_path_and_404s_the_unknown(
    users_client: TestClient, users: FakeUsers
) -> None:
    response = users_client.patch(
        f"{USERS}/A@Example.test", headers=AUTH, json={"status": "revoked"}
    )
    assert response.status_code == 200
    assert users.calls == [("status", ("a@example.test", "revoked"))]
    assert (
        users_client.patch(
            f"{USERS}/a@example.test", headers=AUTH, json={"status": "gone"}
        ).status_code
        == 422
    )
    missing = users_client.patch(
        f"{USERS}/missing@example.test", headers=AUTH, json={"status": "active"}
    )
    assert missing.status_code == 404
    assert missing.json()["type"].endswith("/not-found")


def test_a_non_admin_is_refused_with_a_problem(app: FastAPI) -> None:
    app.dependency_overrides[get_user_service] = lambda: FakeUsers(forbidden=True)
    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.get(USERS, headers=AUTH)
    assert response.status_code == 403
    assert response.json()["type"].endswith("/forbidden")
