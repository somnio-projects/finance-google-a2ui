"""A mounted-but-empty optional credential must mean "unset", not "empty".

Found by deploying `dev`. Secret Manager holds `GEMINI_API_KEY` and
`SENTRY_DSN`; neither had a value yet; Cloud Run mounts both at
`version = "latest"`. The factories branch on `is None`
(`infra/model/factory.py`, `infra/telemetry/factory.py`), so an empty mount
would have produced a Gemini client with no key and `sentry_sdk.init(dsn="")`
instead of the null implementations the comment in `config.py` promises.

Nothing downstream could tell the two apart, which is why the collapse happens
at the boundary and why it is asserted here rather than in the factories.
"""

import pytest
from pydantic import SecretStr

from tests.conftest import make_settings

BLANK = ["", "   ", "\t\n"]


@pytest.mark.parametrize("raw", BLANK, ids=["empty", "spaces", "whitespace"])
def test_settings_blank_gemini_key_is_unset(raw: str) -> None:
    assert make_settings(gemini_api_key=raw).gemini_api_key is None


@pytest.mark.parametrize("raw", BLANK, ids=["empty", "spaces", "whitespace"])
def test_settings_blank_sentry_dsn_is_unset(raw: str) -> None:
    assert make_settings(sentry_dsn=raw).sentry_dsn is None


@pytest.mark.parametrize("raw", BLANK, ids=["empty", "spaces", "whitespace"])
def test_settings_blank_oidc_jwks_url_is_unset(raw: str) -> None:
    assert make_settings(auth_oidc_jwks_url=raw).auth_oidc_jwks_url is None


def test_settings_blank_auth_jwt_secret_is_unset() -> None:
    assert make_settings(auth_jwt_secret="").auth_jwt_secret is None


def test_settings_a_real_credential_survives_untouched() -> None:
    """The guard must not eat a value that merely looks unusual."""
    settings = make_settings(gemini_api_key="  AIza-not-stripped  ")

    assert settings.gemini_api_key is not None
    # Only *blank* is collapsed; a real value is passed through byte for byte,
    # padding included — trimming a credential would be its own silent bug.
    assert settings.gemini_api_key.get_secret_value() == "  AIza-not-stripped  "


def test_settings_a_non_string_value_is_passed_through() -> None:
    """A `SecretStr` arriving already parsed must not hit the string branch."""
    settings = make_settings(gemini_api_key=SecretStr("already-parsed"))

    assert settings.gemini_api_key is not None
    assert settings.gemini_api_key.get_secret_value() == "already-parsed"


def test_the_factories_take_the_null_path_on_a_blank_mount() -> None:
    """The reason the collapse matters, asserted end to end.

    Without the validator both factories take their configured branch with an
    empty credential; this is the assertion that would have gone red.
    """
    from app.infra.model.factory import build_model_client
    from app.infra.telemetry.factory import build_error_reporter

    settings = make_settings(gemini_api_key="", sentry_dsn="")

    assert type(build_model_client(settings)).__name__ == "NullModelClient"
    reporter = build_error_reporter(settings, release="test")
    assert type(reporter).__name__ == "NullErrorReporter"


def test_settings_accepts_the_dev_environment() -> None:
    """`dev` is a deployable environment name (infra/variables.tf).

    It was not in the `Environment` literal when the `dev` environment was
    first applied, so Cloud Run would have started the container with
    `ENVIRONMENT=dev` and killed it on a `ValidationError`. The names are
    compared across the two declarations by
    `infra/scripts/tests/test_dev_environment.sh`; this asserts the backend
    half on its own.
    """
    assert make_settings(environment="dev").environment == "dev"
    assert make_settings(environment="dev").is_production is False
