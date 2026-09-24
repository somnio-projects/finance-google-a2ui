"""``PreviewSignInService`` — the local e-mail sign-in (spec 0027 OD-3)."""

import jwt
import pytest

from app.core.config import Settings
from app.core.errors import FeatureDisabledError, NotProvisionedError
from app.helpers.clock import FixedClock
from app.services.audit_service import AuditService
from app.services.preview_sign_in_service import PROVIDER, PreviewSignInService
from tests.conftest import TEST_AUDIENCE, TEST_ISSUER, TEST_SECRET, make_settings
from tests.unit.services.user_doubles import (
    NOW,
    FakeAuditRepository,
    FakeUserRepository,
)


def make(
    repo: FakeUserRepository, audit: FakeAuditRepository, settings: Settings
) -> PreviewSignInService:
    return PreviewSignInService(
        repository=repo,  # type: ignore[arg-type]
        audit=AuditService(repository=audit),  # type: ignore[arg-type]
        clock=FixedClock(NOW),
        settings=settings,
    )


ENABLED = {"auth_preview_sign_in_enabled": True}


@pytest.mark.parametrize(
    "overrides",
    [
        {},
        {
            **ENABLED,
            "auth_provider": "oidc",
            "auth_oidc_jwks_url": "https://idp.test/jwks",
        },
        {**ENABLED, "auth_jwt_secret": None},
    ],
    ids=["flag-off", "oidc-provider", "no-secret"],
)
async def test_the_route_does_not_exist_unless_the_stack_is_a_local_jwt_one(
    overrides: dict[str, object],
) -> None:
    service = make(
        FakeUserRepository(), FakeAuditRepository(), make_settings(**overrides)
    )
    assert service.enabled is False
    with pytest.raises(FeatureDisabledError):
        await service.sign_in("demo@somnio.dev", request_id="r1")


@pytest.mark.parametrize(
    "status", [None, "requested", "revoked"], ids=["unknown", "requested", "revoked"]
)
async def test_an_unprovisioned_email_is_refused_without_a_token(
    status: str | None,
) -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    if status:
        await repo.upsert(
            email="demo@somnio.dev",
            display_name=None,
            role="member",
            status=status,
            invited_by=None,
        )
    with pytest.raises(NotProvisionedError) as caught:
        await make(repo, audit, make_settings(**ENABLED)).sign_in(
            "demo@somnio.dev", request_id="r1"
        )
    assert caught.value.code == "not-provisioned"
    assert audit.events == []


async def test_a_provisioned_email_gets_a_token_the_jwt_provider_accepts() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="demo@somnio.dev",
        display_name=None,
        role="admin",
        status="invited",
        invited_by=None,
    )
    settings = make_settings(**ENABLED, auth_preview_token_ttl_seconds=600)
    answer = await make(repo, audit, settings).sign_in(
        "demo@somnio.dev", request_id="r1"
    )
    claims = jwt.decode(
        answer.access_token,
        TEST_SECRET,
        algorithms=["HS256"],
        audience=TEST_AUDIENCE,
        issuer=TEST_ISSUER,
        options={"verify_exp": False},
    )
    assert (claims["sub"], claims["email"], claims["roles"]) == (
        "demo@somnio.dev",
        "demo@somnio.dev",
        ["admin"],
    )
    assert claims["exp"] - claims["iat"] == 600 == answer.expires_in
    assert answer.token_type == "Bearer"
    event = audit.events[0]
    assert (event.action, event.target, event.provider) == (
        "user.preview_sign_in",
        "demo@somnio.dev",
        PROVIDER,
    )
    assert answer.access_token not in event.token_fingerprint
