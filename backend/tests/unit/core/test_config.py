import pytest
from pydantic import ValidationError

from app.core.config import Settings, get_settings
from tests.conftest import make_settings


def test_settings_missing_database_url_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ValidationError, match="database_url"):
        Settings.model_validate(
            {"auth_issuer": "x", "auth_audience": "y"}, context={"_env_file": None}
        )


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("a.com, b.com ,", ["a.com", "b.com"]),
        (["a.com"], ["a.com"]),
        ("", []),
    ],
    ids=["csv_string", "list_passthrough", "empty_string"],
)
def test_settings_csv_fields_are_split(raw: object, expected: list[str]) -> None:
    settings = make_settings(cors_allowed_origins=raw, trusted_hosts=raw or ["*"])
    assert settings.cors_allowed_origins == expected


def test_settings_is_production_only_for_production() -> None:
    assert make_settings(environment="production").is_production is True
    assert make_settings(environment="local").is_production is False


def test_settings_database_url_str_keeps_driver() -> None:
    assert make_settings().database_url_str.startswith("postgresql+asyncpg://")


def test_get_settings_is_cached_and_reads_env(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "aud")
    monkeypatch.setenv("AUTH_JWT_SECRET", "s")
    first = get_settings()
    assert first is get_settings()
    assert first.auth_audience == "aud"
    get_settings.cache_clear()


def test_settings_read_csv_lists_from_environment_not_json(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Regression: pydantic-settings JSON-decodes list fields by default, which
    # made `CORS_ALLOWED_ORIGINS=http://a,http://b` crash the container at boot.
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "aud")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://a.test, http://b.test")
    monkeypatch.setenv("TRUSTED_HOSTS", "*")
    settings = Settings(_env_file=None)  # pyright: ignore[reportCallIssue]
    assert settings.cors_allowed_origins == ["http://a.test", "http://b.test"]
    assert settings.trusted_hosts == ["*"]
