"""Access routes at the HTTP layer, the services faked (spec 0027)."""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_preview_sign_in_service, get_user_service
from app.core.errors import FeatureDisabledError, NotProvisionedError
from app.core.principal import Principal
from app.schemas.access import (
    NOT_PROVISIONED_MESSAGE,
    WELCOME_MESSAGE,
    AccessResponse,
    PreviewSignInResponse,
)

AUTH = {"Authorization": "Bearer good"}


class FakeUsers:
    """Answers access for whoever asks and records requests."""

    def __init__(self) -> None:
        self.requested: list[str] = []

    async def access_for(
        self, principal: Principal, *, request_id: str
    ) -> AccessResponse:
        if principal.email == "person@example.test":
            return AccessResponse(
                email=principal.email,
                provisioned=True,
                status="active",
                role="member",
                message=WELCOME_MESSAGE,
            )
        return AccessResponse(
            email=principal.email, provisioned=False, message=NOT_PROVISIONED_MESSAGE
        )

    async def request_access(self, email: str) -> None:
        self.requested.append(email)


class FakePreview:
    """Mints for one e-mail, refuses another, and can be switched off."""

    def __init__(self, *, enabled: bool = True) -> None:
        self.enabled = enabled

    async def sign_in(self, email: str, *, request_id: str) -> PreviewSignInResponse:
        if not self.enabled:
            raise FeatureDisabledError("preview sign-in is not enabled on this stack")
        if email != "demo@somnio.dev":
            raise NotProvisionedError()
        return PreviewSignInResponse(
            access_token="eyJ.test.token", expires_in=600
        )  # gitleaks:allow - test fixture


@pytest.fixture
def users() -> FakeUsers:
    return FakeUsers()


@pytest.fixture
def access_client(app: FastAPI, users: FakeUsers) -> Iterator[TestClient]:
    app.dependency_overrides[get_user_service] = lambda: users
    app.dependency_overrides[get_preview_sign_in_service] = lambda: FakePreview()
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


def test_my_access_needs_a_token_and_answers_the_decision_as_data(
    access_client: TestClient,
) -> None:
    assert access_client.get("/v1/me/access").status_code == 401
    response = access_client.get("/v1/me/access", headers=AUTH)
    assert response.status_code == 200
    assert response.json() == {
        "email": "person@example.test",
        "provisioned": True,
        "status": "active",
        "role": "member",
        "display_name": None,
        "message": WELCOME_MESSAGE,
    }


def test_access_requests_need_no_token_and_never_say_whether_the_email_is_known(
    access_client: TestClient, users: FakeUsers
) -> None:
    first = access_client.post("/v1/access-requests", json={"email": "You@Company.com"})
    second = access_client.post(
        "/v1/access-requests", json={"email": "you@company.com"}
    )
    assert (first.status_code, second.status_code) == (202, 202)
    assert first.content == b""
    assert users.requested == ["you@company.com", "you@company.com"]
    assert (
        access_client.post("/v1/access-requests", json={"email": "nope"}).status_code
        == 422
    )


def test_preview_sign_in_mints_refuses_and_hides(
    access_client: TestClient, app: FastAPI
) -> None:
    minted = access_client.post(
        "/v1/preview-sign-ins", json={"email": "demo@somnio.dev"}
    )
    assert minted.status_code == 201
    assert minted.json()["token_type"] == "Bearer"
    refused = access_client.post(
        "/v1/preview-sign-ins", json={"email": "stranger@example.test"}
    )
    assert refused.status_code == 403
    assert refused.json()["type"].endswith("/not-provisioned")
    assert refused.json()["detail"] == NOT_PROVISIONED_MESSAGE
    app.dependency_overrides[get_preview_sign_in_service] = lambda: FakePreview(
        enabled=False
    )
    hidden = access_client.post(
        "/v1/preview-sign-ins", json={"email": "demo@somnio.dev"}
    )
    assert hidden.status_code == 404
    assert hidden.json()["type"].endswith("/feature-disabled")


def test_the_real_preview_service_is_off_by_default(client: TestClient) -> None:
    """Resolves the real provider: closed settings answer 404 before any database."""
    response = client.post("/v1/preview-sign-ins", json={"email": "demo@somnio.dev"})
    assert response.status_code == 404
    assert response.json()["type"].endswith("/feature-disabled")


def test_the_real_user_service_reaches_for_the_database(client: TestClient) -> None:
    """Resolves the real provider: an unreachable database is a typed 503."""
    response = client.get("/v1/me/access", headers=AUTH)
    assert response.status_code == 503
    assert response.json()["type"].endswith("/dependency-unavailable")
