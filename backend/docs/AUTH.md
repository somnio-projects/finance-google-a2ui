# Authentication

## Contract

Every route except `/healthz`, `/readyz`, `/openapi.json`, `/docs` requires

```
Authorization: Bearer <token>
```

The token is a short-lived **ID token** (never a refresh token). Rejections
are RFC 9457 problems with a stable `type`:

| `type` suffix | HTTP | Client action |
|---|---|---|
| `auth/missing-token` | 401 | sign in |
| `auth/invalid-token` | 401 | sign out (signature, issuer, audience, malformed, unknown key) |
| `auth/expired-token` | 401 | force-refresh the token and retry **once** |
| `forbidden` | 403 | the caller lacks a scope |
| `rate-limited` | 429 | back off, honour `Retry-After` |

## Providers

`AUTH_PROVIDER` selects the `TokenVerifier` in `app/auth/registry.py`:

| Provider | Algorithm | Settings | Use |
|---|---|---|---|
| `jwt` | HS256 shared secret | `AUTH_JWT_SECRET`, `AUTH_ISSUER`, `AUTH_AUDIENCE` | local dev, service-to-service |
| `oidc` | RS256/ES256 via JWKS | `AUTH_OIDC_JWKS_URL`, `AUTH_ISSUER`, `AUTH_AUDIENCE` | Firebase Auth, Google Identity, Auth0, Okta, any OIDC SSO |

Both require `exp`, `iat`, `sub` and validate `iss`/`aud` with
`AUTH_LEEWAY_SECONDS` tolerance. Scopes are read from `scope`, `scp` or
`roles` and lower-cased into `Principal.scopes`.

### Firebase (project `finance-a2ui`)

```
AUTH_PROVIDER=oidc
AUTH_ISSUER=https://securetoken.google.com/finance-a2ui
AUTH_AUDIENCE=finance-a2ui
AUTH_OIDC_JWKS_URL=https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
```

The JWKS is cached for one hour (`JwksKeyResolver`); an unreachable IdP yields
`dependency-unavailable` (503), not a 401.

## Adding a provider (OAuth introspection, SAML bridge, API keys…)

1. Create `app/auth/providers/<name>_provider.py` with a class exposing `name`
   and `async def verify(self, token: str) -> Principal`. Translate every SDK
   error into `AuthenticationError`/`ExpiredTokenError`; never let library
   text reach the caller.
2. Build the `Principal` with `auth.claims.principal_from_claims` so scope
   handling stays uniform.
3. Register a factory in `auth/registry.py::FACTORIES` and add the literal to
   `core/config.py::AuthProviderName`, plus its settings.
4. Tests: `tests/unit/auth/test_<name>_provider.py` covering accept, expired,
   invalid signature, wrong issuer/audience, missing `sub`.
5. Document the settings here and in `env.example`.

Controllers and services do not change.

## Authorization

Services decide with `principal.has_scope("...")` and raise
`AuthorizationError`. Controllers never inspect claims.

## Audit

`IdentityService.describe` records `identity.read` in `audit_events` with the
subject, provider, token fingerprint and request id. Future privileged actions
must call `AuditService.record` the same way.
