"""Authentication: pluggable bearer-token verifiers.

The API only ever sees a ``Principal`` (``app.core.principal``). Which
identity provider produced it (local JWT, OIDC / SSO such as Firebase or
Google) is decided in ``app.auth.registry`` from settings — adding a provider
means adding one module and one registry entry, never touching controllers
or services.
"""

__all__: list[str] = []
