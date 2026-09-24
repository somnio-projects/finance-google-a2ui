"""The authentication half of `Settings` (spec 0040).

Split out when `config.py` reached the 150-line budget, along the seam
`view_options.py` / `view_options_tabs.py` already draws: one mixin per
concern, composed into the one model everything reads. `Settings` still has
every field on it, so no call site changes and `SETTINGS_` prefixes are
unaffected — this is a file boundary, not a configuration boundary.
"""

from typing import Literal

from pydantic import Field, SecretStr

from app.core.config_parsing import CsvList

#: Which verifier the deployment uses. A new provider is a new member here
#: plus a factory in `app.auth.registry`, and nothing else.
AuthProviderName = Literal["jwt", "oidc"]


class AuthSettings:
    """Who the caller is, and who is allowed in.

    A plain class, like `CsvParsing`: pydantic collects fields from the
    bases, so `Settings` gains these by inheriting. **Fields only** — the
    derived `admin_mfa_required` stays on `Settings` because it reads
    `is_production`, and an environment is not an authentication setting.
    """

    # --- authentication ----------------------------------------------------
    auth_provider: AuthProviderName = "jwt"
    auth_audience: str
    auth_issuer: str
    auth_jwt_secret: SecretStr | None = None
    auth_oidc_jwks_url: str | None = None
    auth_leeway_seconds: int = Field(default=30, ge=0, le=300)
    auth_admin_require_mfa: bool | None = None  # None = required in production only
    auth_bootstrap_admins: CsvList = Field(default_factory=list)  # spec 0027
    auth_open_enrolment: bool = False  # spec 0040; off = invite-only
    auth_preview_sign_in_enabled: bool = False
    auth_preview_token_ttl_seconds: int = Field(default=28_800, ge=300, le=86_400)


__all__ = ["AuthSettings"]
