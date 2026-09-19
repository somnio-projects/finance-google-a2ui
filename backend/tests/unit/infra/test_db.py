import pytest
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncEngine

from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory, session_scope
from tests.conftest import make_settings


class FailingEngine:
    """Engine double whose ``connect`` raises like a down database."""

    def __init__(self, error: BaseException) -> None:
        self._error = error

    def connect(self) -> "FailingEngine":
        return self

    async def __aenter__(self) -> "FailingEngine":
        raise self._error

    async def __aexit__(
        self, *args: object
    ) -> None:  # pragma: no cover - never reached
        return None


def test_create_engine_uses_settings_pool_size() -> None:
    engine = create_engine(make_settings(database_pool_size=7))
    assert isinstance(engine, AsyncEngine)
    assert engine.pool.size() == 7  # type: ignore[attr-defined]
    assert engine.dialect.name == "postgresql"


@pytest.mark.parametrize(
    "error",
    [OperationalError("SELECT 1", {}, Exception("down")), ConnectionRefusedError()],
    ids=["sqlalchemy_error", "os_error"],
)
async def test_readiness_probe_returns_false_when_connect_fails(
    error: BaseException,
) -> None:
    probe = DatabaseReadinessProbe(FailingEngine(error))  # type: ignore[arg-type]
    assert probe.name == "database"
    assert await probe.check() is False


class FakeSession:
    def __init__(self) -> None:
        self.calls: list[str] = []

    async def commit(self) -> None:
        self.calls.append("commit")

    async def rollback(self) -> None:
        self.calls.append("rollback")

    async def close(self) -> None:
        self.calls.append("close")


async def test_session_scope_commits_and_closes_on_success() -> None:
    session = FakeSession()
    async with session_scope(lambda: session):  # type: ignore[arg-type]
        pass
    assert session.calls == ["commit", "close"]


async def test_session_scope_rolls_back_and_reraises_on_error() -> None:
    session = FakeSession()
    with pytest.raises(RuntimeError, match="boom"):
        async with session_scope(lambda: session):  # type: ignore[arg-type]
            raise RuntimeError("boom")
    assert session.calls == ["rollback", "close"]


def test_create_session_factory_binds_engine() -> None:
    engine = create_engine(make_settings())
    factory = create_session_factory(engine)
    assert factory.kw["bind"] is engine
    assert factory.kw["expire_on_commit"] is False
