import pytest

from app.auth.principal import Principal
from app.core.errors import AuthenticationError, MissingTokenError
from app.services.auth_service import AuthService
from tests.conftest import FakeReporter, FakeVerifier


@pytest.fixture
def service(principal: Principal, reporter: FakeReporter) -> AuthService:
    return AuthService(verifier=FakeVerifier(principal), reporter=reporter)


async def test_authenticate_returns_principal_and_counts_accept(
    service: AuthService, principal: Principal, reporter: FakeReporter
) -> None:
    result = await service.authenticate("Bearer good")
    assert result == principal
    assert reporter.metrics == [("auth.accepted", {"provider": "fake"})]


@pytest.mark.parametrize(
    "header",
    [None, "", "Basic abc", "Bearer "],
    ids=["none", "empty", "basic", "blank"],
)
async def test_authenticate_without_bearer_raises_missing_token(
    service: AuthService, reporter: FakeReporter, header: str | None
) -> None:
    with pytest.raises(MissingTokenError):
        await service.authenticate(header)
    assert reporter.metrics == [("auth.rejected", {"code": "missing-token"})]


async def test_authenticate_rejected_token_counts_code_and_reraises(
    service: AuthService, reporter: FakeReporter
) -> None:
    with pytest.raises(AuthenticationError):
        await service.authenticate("Bearer bad")
    assert reporter.metrics == [("auth.rejected", {"code": "auth/invalid-token"})]
