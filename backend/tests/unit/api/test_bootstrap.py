import pytest
from fastapi.testclient import TestClient
from pytest_mock import MockerFixture
from sqlalchemy.ext.asyncio import AsyncEngine

from app import __version__
from app.auth.providers.jwt_provider import JwtTokenVerifier
from app.bootstrap import build_container, create_app
from app.infra.telemetry.null_reporter import NullErrorReporter
from tests.conftest import make_settings
from tests.unit.api.conftest import UNREACHABLE_DSN


def test_build_container_wires_defaults_from_settings() -> None:
    container = build_container(make_settings(database_url=UNREACHABLE_DSN))
    assert isinstance(container.verifier, JwtTokenVerifier)
    assert isinstance(container.reporter, NullErrorReporter)
    assert container.health.liveness().version == __version__


def test_create_app_from_settings_serves_and_disposes_engine_on_shutdown(
    mocker: MockerFixture,
) -> None:
    settings = make_settings(database_url=UNREACHABLE_DSN, trusted_hosts=["*"])
    app = create_app(settings)
    dispose = mocker.patch.object(AsyncEngine, "dispose", autospec=True)
    with TestClient(app) as client:
        assert client.get("/health").json()["version"] == __version__
        assert app.title == settings.app_name
    dispose.assert_awaited_once()


def test_create_app_without_arguments_reads_the_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.core.config import get_settings

    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", UNREACHABLE_DSN)
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "aud")
    monkeypatch.setenv("AUTH_JWT_SECRET", "s")
    app = create_app()
    assert app.state.container.settings.auth_audience == "aud"
    get_settings.cache_clear()


def test_main_module_builds_the_asgi_app_from_the_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import importlib
    import sys

    from app.core.config import get_settings

    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", UNREACHABLE_DSN)
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "aud")
    monkeypatch.setenv("AUTH_JWT_SECRET", "s")
    sys.modules.pop("app.main", None)
    module = importlib.import_module("app.main")
    assert module.app.title == "finance-a2ui-backend"
    get_settings.cache_clear()
