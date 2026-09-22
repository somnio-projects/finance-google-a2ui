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
    production = make_settings(environment="production", trusted_hosts=["api.test"])
    assert production.is_production is True
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


def test_settings_reject_wildcard_cors_origin() -> None:
    with pytest.raises(ValidationError, match="never '\\*'"):
        make_settings(cors_allowed_origins=["*"])


def test_settings_reject_wildcard_trusted_hosts_in_production() -> None:
    with pytest.raises(ValidationError, match="TRUSTED_HOSTS must be an explicit list"):
        make_settings(environment="production", trusted_hosts=["*"])
    assert make_settings(environment="production", trusted_hosts=["api.test"])


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


@pytest.mark.parametrize(
    ("environment", "override", "expected"),
    [
        ("production", None, True),
        ("local", None, False),
        ("local", True, True),
        ("production", False, False),
    ],
    ids=["prod_default", "local_default", "local_forced_on", "prod_forced_off"],
)
def test_settings_admin_mfa_required_follows_environment_unless_set(
    environment: str, override: bool | None, expected: bool
) -> None:
    settings = make_settings(
        environment=environment,
        trusted_hosts=["api.example"],
        auth_admin_require_mfa=override,
    )
    assert settings.admin_mfa_required is expected


def test_settings_audit_retention_defaults_to_thirteen_months() -> None:
    assert make_settings().audit_retention_days == 400


def test_provisioning_settings_default_to_closed() -> None:
    settings = make_settings()
    assert settings.auth_bootstrap_admins == []
    assert settings.auth_preview_sign_in_enabled is False
    assert settings.auth_preview_token_ttl_seconds == 28_800


def test_bootstrap_admins_are_read_as_a_csv_from_the_environment() -> None:
    # The local stack hands the list over as one string; a JSON list it is not.
    settings = make_settings(auth_bootstrap_admins="demo@somnio.dev, root@x.test")
    assert settings.auth_bootstrap_admins == ["demo@somnio.dev", "root@x.test"]
