---
description: Backend security controls mapped to SOC 2 TSC and ISO/IEC 27001 Annex A — auth, secrets, logging, error responses, dependencies, containers. Loads when touching backend code, Docker or compose files.
paths:
  - "backend/src/**/*.py"
  - "backend/alembic/**/*.py"
  - "backend/Dockerfile"
  - "backend/docker/**"
  - "docker-compose.yml"
alwaysApply: false
---

# Backend security rules (SOC 2 · ISO/IEC 27001)

The full control mapping is `backend/docs/SECURITY.md`. These are the rules that apply while writing code.

## Authentication & authorization (CC6.1, CC6.3 · A.5.15, A.5.17, A.8.5)

- Every route is authenticated through `PrincipalDep` except `/health`, `/readyz`, `/openapi.json`, `/docs`, `/.well-known/agent-card.json` and the three routes a person reaches *before* they have a token — `POST /v1/access-requests`, `POST /v1/preview-sign-ins` and `GET /v1/sign-in-policy` (specs 0027 and 0043). Adding a public route requires a note in the feature spec and the reviewer's sign-off. The agent card is public because a client cannot present a token before it has bootstrapped (spec 0010 OD-1); it carries no subject data, only what the service is and what it can be asked for. The list is spelled out in `tests/unit/api/test_openapi_contract.py::PUBLIC`, so adding one is a visible diff rather than a route that quietly stops declaring a 401.
- Only Firebase/OIDC ID tokens or HS256 service tokens are accepted; refresh tokens, API keys in query strings and cookies are never credentials.
- Verify `iss`, `aud`, `exp`, `iat` and signature; require `sub`. Leeway ≤ 300 s.
- Authorization decisions (scopes/roles) live in services, using `principal.has_scope(...)`; never in controllers, never by string comparison on raw claims.

## Secrets & configuration (CC6.1, CC6.7 · A.5.33, A.8.24)

- No secret in code, tests, fixtures, images, logs or error bodies. `SecretStr` for every credential in `Settings`; `.get_secret_value()` only at the adapter that consumes it.
- Required settings have no defaults; a missing value must crash at startup, never fall back.
- `.env*` files are denied to the agent; `env.example` documents variables with placeholder values only.

## Logging & audit (CC7.2, CC7.3 · A.8.15, A.8.16)

- structlog JSON only; every entry carries `request_id`. Never log tokens, passwords, full `Authorization` headers, or PII (emails count). Use `token_fingerprint`.
- Security-relevant actions (login/identity reads, privileged operations, data exports) are written to `audit_events` through `AuditService.record`. Actions are named `<domain>.<verb>`.
- Rejections are logged with their error code (`auth/expired-token`), never with the reason text of the library.

## Error handling & responses (CC7.4 · A.8.9)

- All errors leave as RFC 9457 problem details. Detail text must be safe for an anonymous caller: no stack traces, no SQL, no file paths, no library messages.
- Unexpected exceptions go to `ErrorReporter.capture_exception` and return the generic `internal` problem.

## Transport & HTTP hardening (CC6.6, CC6.7 · A.8.20, A.8.26)

- Keep `SecurityHeadersMiddleware`, `TrustedHostMiddleware`, CORS allow-list, body limit and rate limiter in `api/middleware/install.py::install_middleware`, in that order — outermost request id, innermost rate limit. Reordering them is a security change. Never widen CORS to `*` with credentials; never disable HSTS in production.
- New endpoints that accept bodies define pydantic models with explicit `max_length`/bounds.

## Data (CC6.5 · A.8.10, A.8.12)

- Persist the minimum: prefer fingerprints/ids over raw identifiers. Every table has `created_at`; deletions of personal data need a documented retention decision in the spec.
- Parameterised queries only (SQLAlchemy expressions). Raw `text()` is limited to health probes and migrations.

## Supply chain & runtime (CC8.1 · A.8.8, A.8.19, A.8.31)

- Dependencies pinned through `uv.lock`; `make audit` (pip-audit) and gitleaks run in CI; new dependencies are named in the PR with the reason.
- Container runs as non-root (`uid 10001`), read-only filesystem, `no-new-privileges`, health check on `/health`; nothing but the runtime and source is copied into the image.
- Migrations are the only schema path (`alembic upgrade head`); no `create_all` outside tests.
