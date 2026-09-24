"""`GET /v1/sign-in-policy` — the door, asked before anybody has a token.

Spec 0043. Three things are worth a test here and each is one of the claims
the route makes: the answer follows the switch, it needs no credential, and
it is the same for a caller who has one.
"""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.schemas.sign_in_policy import INVITE_ONLY, OPEN, SignInPolicy
from tests.conftest import FakeReporter, make_settings
from tests.unit.api.app_factory import make_app
from tests.unit.api.conftest import UNREACHABLE_DSN

PATH = "/v1/sign-in-policy"


def policy_client(
    *,
    open_enrolment: bool,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> Iterator[TestClient]:
    """A client whose app has the enrolment switch in the given position."""
    settings = make_settings(
        database_url=UNREACHABLE_DSN,
        rate_limit_per_minute=200,
        trusted_hosts=["testserver", "localhost"],
        auth_open_enrolment=open_enrolment,
    )
    app = make_app(settings, principal=principal, clock=clock, reporter=reporter)
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client


@pytest.mark.parametrize(
    ("open_enrolment", "expected"),
    [(True, OPEN), (False, INVITE_ONLY)],
    ids=["open", "invite-only"],
)
def test_sign_in_policy_follows_the_enrolment_switch(
    *,
    open_enrolment: bool,
    expected: str,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> None:
    for client in policy_client(
        open_enrolment=open_enrolment,
        principal=principal,
        clock=clock,
        reporter=reporter,
    ):
        response = client.get(PATH)
        assert response.status_code == 200
        assert response.json() == {"enrolment": expected}


def test_sign_in_policy_answers_without_a_token(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> None:
    """Public by contract: the screen asks before it can present one."""
    for client in policy_client(
        open_enrolment=True, principal=principal, clock=clock, reporter=reporter
    ):
        assert client.get(PATH).status_code == 200


def test_sign_in_policy_answers_a_signed_in_caller_the_same_thing(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> None:
    """Nothing about it is per-caller, so a token must not change the answer."""
    for client in policy_client(
        open_enrolment=False, principal=principal, clock=clock, reporter=reporter
    ):
        anonymous = client.get(PATH).json()
        authenticated = client.get(PATH, headers={"Authorization": "Bearer good"})
        assert authenticated.json() == anonymous == {"enrolment": INVITE_ONLY}


@pytest.mark.parametrize(
    ("open_enrolment", "expected"),
    [(True, OPEN), (False, INVITE_ONLY)],
    ids=["open", "invite-only"],
)
def test_sign_in_policy_of_names_the_door(
    *, open_enrolment: bool, expected: str
) -> None:
    """The DTO's own factory, without the HTTP layer around it."""
    assert SignInPolicy.of(open_enrolment=open_enrolment).enrolment == expected
