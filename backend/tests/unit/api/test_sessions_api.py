"""Session routes at the HTTP layer, with no database behind them.

The DSN points at a refused port, so anything that reaches the repository
answers 503 — which is exactly what AC-9 claims. Rows live in
``tests/integration``.
"""

import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_session_service
from app.core.errors import DependencyUnavailableError
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.schemas.sessions import SessionResponse
from tests.conftest import FROZEN_NOW, FakeReporter
from tests.unit.api.conftest import make_session_app

SESSIONS = "/v1/sessions"
AUTH = {"Authorization": "Bearer good"}
SOME_ID = "9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31"

ROUTES = [
    ("post", SESSIONS, {"title": "x"}),
    ("get", SESSIONS, None),
    ("get", f"{SESSIONS}/{SOME_ID}", None),
    ("delete", f"{SESSIONS}/{SOME_ID}", None),
    ("post", f"{SESSIONS}/{SOME_ID}/messages", {"role": "user", "content": "hi"}),
    ("get", f"{SESSIONS}/{SOME_ID}/messages", None),
]
ROUTE_IDS = ["create", "list", "read", "delete", "append", "conversation"]


@pytest.fixture
def flag_off_client(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> Iterator[TestClient]:
    app = make_session_app(
        principal, clock, reporter, feature_flags_force_disabled=["sessions.api"]
    )
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


class FakeSessions:
    """Service double: lets the controller run without a database behind it."""

    def __init__(self) -> None:
        self.created = SessionResponse(
            id=uuid.uuid4(),
            title="Retirement review",
            created_at=FROZEN_NOW,
            updated_at=FROZEN_NOW,
        )

    async def create(
        self, principal: Principal, *, title: str | None, request_id: str
    ) -> SessionResponse:
        return self.created


@pytest.mark.parametrize(("method", "path", "body"), ROUTES, ids=ROUTE_IDS)
def test_routes_require_a_bearer_token(
    sessions_client: TestClient, method: str, path: str, body: dict[str, str] | None
) -> None:
    """Spec 0004 AC-7: no token, no session — on every route."""
    response = sessions_client.request(method, path, json=body)
    assert response.status_code == 401
    assert response.json()["type"].endswith("/auth/missing-token")


@pytest.mark.parametrize(("method", "path", "body"), ROUTES, ids=ROUTE_IDS)
def test_routes_are_404_while_the_flag_is_off(
    flag_off_client: TestClient, method: str, path: str, body: dict[str, str] | None
) -> None:
    """Spec 0004 AC-7: the gate answers before the route body runs."""
    response = flag_off_client.request(method, path, json=body, headers=AUTH)
    assert response.status_code == 404
    assert response.json()["type"].endswith("/feature-disabled")


def test_database_failure_is_503(
    sessions_client: TestClient, reporter: FakeReporter
) -> None:
    """Spec 0004 AC-9: the caller sees a typed problem, never the driver."""
    response = sessions_client.post(SESSIONS, json={"title": "x"}, headers=AUTH)
    assert response.status_code == 503
    body = response.json()
    assert body["type"].endswith("/dependency-unavailable")
    assert "sqlalchemy" not in body["detail"].lower()
    assert "traceback" not in response.text.lower()
    assert all(
        isinstance(exc, DependencyUnavailableError) for exc in reporter.exceptions
    )


def test_create_answers_201_with_a_location_header(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> None:
    """Spec 0004 AC-1: the created session is addressable from the response."""
    app = make_session_app(principal, clock, reporter)
    service = FakeSessions()
    app.dependency_overrides[get_session_service] = lambda: service
    with TestClient(app) as client:
        response = client.post(SESSIONS, json={"title": "x"}, headers=AUTH)
    app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.headers["Location"] == f"{SESSIONS}/{service.created.id}"
    assert response.json()["id"] == str(service.created.id)
