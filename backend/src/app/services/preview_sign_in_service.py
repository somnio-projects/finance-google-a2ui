"""The local e-mail sign-in (spec 0027 OD-3) — a bearer token for the dev stack.

Firebase is the identity provider everywhere a browser can reach it. A local
stack has no Firebase, so the design's *Continue with email* needs something
to answer it: this mints the same HS256 token ``make token`` mints, but only
for a **provisioned** e-mail and only while ``AUTH_PROVIDER=jwt`` and
``AUTH_PREVIEW_SIGN_IN_ENABLED`` both hold. Under ``oidc`` — every deployed
environment — the route answers 404 as if it did not exist.
"""

from app.auth.dev_tokens import build_token
from app.core.config import Settings
from app.core.errors import FeatureDisabledError, NotProvisionedError
from app.core.principal import Principal
from app.core.protocols import Clock
from app.helpers.tokens import fingerprint
from app.repositories.user_repository import UserRepository
from app.schemas.access import PROVISIONED, PreviewSignInResponse
from app.services.audit_service import AuditService

PROVIDER = "preview"


class PreviewSignInService:
    """Exchange a provisioned e-mail for a development bearer token."""

    def __init__(
        self,
        *,
        repository: UserRepository,
        audit: AuditService,
        clock: Clock,
        settings: Settings,
    ) -> None:
        """Bind the registry, the audit trail, the clock and the auth settings."""
        self._repository = repository
        self._audit = audit
        self._clock = clock
        self._settings = settings

    @property
    def enabled(self) -> bool:
        """Whether this stack may mint tokens at all."""
        settings = self._settings
        return (
            settings.auth_preview_sign_in_enabled
            and settings.auth_provider == "jwt"
            and settings.auth_jwt_secret is not None
        )

    async def sign_in(self, email: str, *, request_id: str) -> PreviewSignInResponse:
        """Mint a token for ``email`` if it is provisioned; audit the sign-in."""
        secret = self._settings.auth_jwt_secret
        if not self.enabled or secret is None:
            raise FeatureDisabledError("preview sign-in is not enabled on this stack")
        row = await self._repository.find_by_email(email)
        if row is None or row.status not in PROVISIONED:
            raise NotProvisionedError()
        ttl = self._settings.auth_preview_token_ttl_seconds
        token = build_token(
            subject=email,
            secret=secret.get_secret_value(),
            issuer=self._settings.auth_issuer,
            audience=self._settings.auth_audience,
            ttl_seconds=ttl,
            now=self._clock.now(),
            extra={"email": email, "roles": [row.role]},
        )
        principal = Principal(
            subject=email,
            provider=PROVIDER,
            email=email,
            scopes=frozenset({row.role}),
            token_fingerprint=fingerprint(token),
        )
        await self._audit.record(
            principal,
            action="user.preview_sign_in",
            request_id=request_id,
            target=email,
        )
        return PreviewSignInResponse(access_token=token, expires_in=ttl)


__all__ = ["PROVIDER", "PreviewSignInService"]
