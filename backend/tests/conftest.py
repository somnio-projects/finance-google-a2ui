"""Fixtures shared by unit and integration tests.

Unit tests never touch I/O: they use the fakes below. Integration tests add
a real PostgreSQL in ``tests/integration/conftest.py``.
"""

import uuid
from collections.abc import Mapping
from datetime import UTC, datetime

import jwt
import pytest

from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock

TEST_SECRET = "unit-test-secret-please-do-not-reuse-0123456789abcdef"
TEST_ISSUER = "https://issuer.test"
TEST_AUDIENCE = "finance-a2ui-test"
FROZEN_NOW = datetime(2026, 9, 18, 12, 0, tzinfo=UTC)


class FakeReporter:
    """In-memory ``ErrorReporter`` that records every call."""

    def __init__(self) -> None:
        self.exceptions: list[BaseException] = []
        self.metrics: list[tuple[str, dict[str, str]]] = []

    def capture_exception(self, exc: BaseException) -> None:
        self.exceptions.append(exc)

    def increment(self, metric: str, *, tags: Mapping[str, str] | None = None) -> None:
        self.metrics.append((metric, dict(tags or {})))


class FakeVerifier:
    """``TokenVerifier`` that accepts one token and rejects everything else."""

    name = "fake"

    def __init__(self, principal: Principal, *, accepts: str = "good") -> None:
        self.principal = principal
        self.accepts = accepts

    async def verify(self, token: str) -> Principal:
        from app.core.errors import AuthenticationError

        if token != self.accepts:
            raise AuthenticationError()
        return self.principal


def make_settings(**overrides: object) -> Settings:
    """Build valid test settings without reading any ``.env`` file."""
    values: dict[str, object] = {
        "environment": "test",
        "database_url": "postgresql+asyncpg://app:app@localhost:5432/test",
        "auth_provider": "jwt",
        "auth_issuer": TEST_ISSUER,
        "auth_audience": TEST_AUDIENCE,
        "auth_jwt_secret": TEST_SECRET,
        "cors_allowed_origins": ["http://localhost:3000"],
    }
    values.update(overrides)
    return Settings.model_validate(values, context={"_env_file": None})


def make_token(
    *,
    subject: str | None = None,
    now: datetime = FROZEN_NOW,
    ttl_seconds: int = 300,
    secret: str = TEST_SECRET,
    extra: Mapping[str, object] | None = None,
) -> str:
    """Mint an HS256 token accepted by the test settings."""
    claims: dict[str, object] = {
        "sub": subject or f"user-{uuid.uuid4()}",
        "iss": TEST_ISSUER,
        "aud": TEST_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int(now.timestamp()) + ttl_seconds,
    }
    claims.update(extra or {})
    return jwt.encode(claims, secret, algorithm="HS256")


@pytest.fixture(autouse=True)
def _never_read_dotenv(monkeypatch: pytest.MonkeyPatch) -> None:
    """Tests build settings from explicit values only, never from ``backend/.env``.

    A developer's real ``.env`` would otherwise leak into tests that assert
    fail-fast behaviour (``.claude/rules/backend/testing.md``).
    """
    monkeypatch.setitem(Settings.model_config, "env_file", None)


@pytest.fixture
def settings() -> Settings:
    return make_settings()


@pytest.fixture
def clock() -> FixedClock:
    return FixedClock(FROZEN_NOW)


@pytest.fixture
def reporter() -> FakeReporter:
    return FakeReporter()


@pytest.fixture
def principal() -> Principal:
    return Principal(
        subject=f"user-{uuid.uuid4()}",
        provider="fake",
        email="person@example.test",
        scopes=frozenset({"read"}),
        token_fingerprint="0123456789abcdef",  # gitleaks:allow - test fixture
    )
