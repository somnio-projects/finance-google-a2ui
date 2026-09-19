import pytest

from app.bootstrap import build_container
from app.core.errors import DependencyUnavailableError
from app.jobs import purge_audit
from tests.conftest import make_settings

UNREACHABLE_DSN = "postgresql+asyncpg://app:app@127.0.0.1:1/finance"


async def test_run_translates_unreachable_database_to_dependency_error() -> None:
    container = build_container(make_settings(database_url=UNREACHABLE_DSN))
    try:
        with pytest.raises(DependencyUnavailableError, match="write failed"):
            await purge_audit.run(container)
    finally:
        await container.engine.dispose()


async def test_main_reads_settings_from_environment_and_disposes_engine(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.core.config import get_settings

    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", UNREACHABLE_DSN)
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "a")
    monkeypatch.setenv("AUTH_JWT_SECRET", "x" * 48)
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
    try:
        with pytest.raises(DependencyUnavailableError, match="write failed"):
            await purge_audit.main()
    finally:
        get_settings.cache_clear()
