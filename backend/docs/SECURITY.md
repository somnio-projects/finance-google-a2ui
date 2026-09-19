# Security controls — SOC 2 (TSC 2017) and ISO/IEC 27001:2022 mapping

This service is a public open-source reference application holding a
third-party model key server-side. The controls below are implemented in code
or configuration and verified by tests; each row names where.

## Control matrix

| Control | Implementation | Verified by | SOC 2 TSC | ISO 27001 Annex A |
|---|---|---|---|---|
| Authenticate every request except health/docs | `api/deps.py::get_current_principal`, `services/auth_service.py` | `tests/unit/api/test_identity_auth.py`, `tests/integration/test_identity_flow.py` | CC6.1, CC6.3 | A.5.15, A.8.5 |
| Verify token signature, issuer, audience, expiry; require `sub` | `auth/providers/jwt_provider.py`, `oidc_provider.py` | `tests/unit/auth/*` | CC6.1 | A.8.5 |
| Distinguishable auth error codes, no library text | `core/errors.py`, `api/errors.py` | `test_jwt_provider.py`, `test_identity_auth.py` | CC7.4 | A.8.9 |
| Secrets only from environment, typed `SecretStr`, fail-fast | `core/config.py` | `tests/unit/core/test_config.py` | CC6.1, CC6.7 | A.5.33, A.8.24 |
| No secrets in repo/image; `.env` denied to tooling | `.claude/settings.json`, `.dockerignore`, gitleaks in CI | CI `secrets` job | CC6.7, CC8.1 | A.8.24 |
| Structured logs without credentials/PII | `core/logging.py::redact_sensitive`, request-id binding | `tests/unit/core/test_logging.py` | CC7.2 | A.8.15 |
| Audit trail of identity actions | `models/audit_event.py`, `services/audit_service.py` | `test_identity_flow.py`, `test_repositories.py` | CC7.2, CC7.3 | A.8.15, A.8.16 |
| Credential never stored — fingerprint only | `helpers/tokens.py::fingerprint` | `tests/unit/helpers/test_tokens.py` | CC6.7 | A.8.5 |
| Security response headers, CSP, HSTS (prod) | `api/middleware/security_headers.py` | `tests/unit/api/test_middleware.py` | CC6.6 | A.8.26 |
| CORS and Host allow-lists | `bootstrap._install_middleware` | `test_middleware.py` | CC6.6 | A.8.20 |
| Request body size limit | `api/middleware/body_limit.py` | `test_middleware.py` | CC6.6 | A.8.6 |
| Per-token rate limit (compensating control for no allow-list) | `api/middleware/rate_limit.py` | `test_middleware.py` | CC6.6 | A.8.6 |
| Unhandled errors reported, masked to clients | `api/errors.py`, `infra/telemetry/*` | `test_error_handlers.py`, `test_telemetry.py` | CC7.2, CC7.4 | A.8.16 |
| Telemetry without PII or request bodies | `infra/telemetry/sentry_reporter.py` (`send_default_pii=False`, `max_request_body_size="never"`) | `test_telemetry.py` | P4.1 | A.8.11 |
| Parameterised SQL only | SQLAlchemy Core/ORM expressions | code review (`backend-reviewer`) | CC6.1 | A.8.28 |
| Schema changes via migrations | `alembic/` | integration suite runs `alembic upgrade head` | CC8.1 | A.8.32 |
| Non-root, read-only container, no-new-privileges, health check | `Dockerfile`, `docker-compose.yml` | CI `image` job (uid check) | CC6.8 | A.8.9, A.8.19 |
| Pinned dependencies, vulnerability scan | `uv.lock`, `pip-audit` in gate | CI `py.audit` | CC8.1 | A.8.8 |
| Docs/OpenAPI hidden in production | `bootstrap.create_app` | `test_middleware.py::test_production_enables_hsts_and_hides_docs` | CC6.6 | A.8.9 |
| 100 % branch coverage, typed strict | `pyproject.toml` gate | CI | CC8.1 | A.8.25, A.8.29 |
| Admin operations require MFA in production (`amr` claim) | `core/principal.py::is_mfa`, `services/feature_flag_service.py::_require_admin`, `Settings.admin_mfa_required` | `tests/unit/services/test_feature_flag_admin_mfa.py`, `tests/unit/core/test_principal.py`, `test_config.py` | CC6.1, CC6.3 | A.5.17, A.8.2, A.8.5 |
| Token payload and JWKS validated through pydantic before use | `auth/claims.py::JwtClaims`, `auth/providers/jwks.py::JwksDocument` | `tests/unit/auth/test_claims.py`, `test_jwks.py` | CC6.1 | A.8.28 |
| Audit-trail retention with purge job | `repositories/audit_repository.py::purge_older_than`, `services/audit_service.py::purge_expired`, `scripts/purge_audit_events.py`, `AUDIT_RETENTION_DAYS` | `tests/integration/test_repositories.py`, `tests/unit/services/test_audit_and_identity.py` | C1.2 | A.8.10 |
| Corrupt stored rows surface as a typed 503, never a 500 | `core/dto.py::from_row` | `tests/unit/core/test_dto.py` | CC7.4 | A.8.9 |
| SAST, secret and image scanning on every PR; weekly independent scan with SBOM | `.github/workflows/backend-ci.yaml` (`sast`, `secrets`, `image`), `.github/workflows/scheduled-scan.yaml` | CI | CC7.1, CC8.1 | A.8.8, A.8.29, A.5.21 |
| Review ownership and change control | `.github/CODEOWNERS`, `.github/pull_request_template.md`; `main` ruleset exported to `docs/compliance/evidence/` (enforcement pending — enabled by the repo admin before merge) | GitHub ruleset export | CC8.1 | A.8.32 |

## Governance, tenancy and data (out of code)

- **Single-tenant by design**; user isolation by `principal.subject` — `docs/compliance/DATA_RESIDENCY_AND_TENANCY.md`.
- Data classes, retention (400 days for `audit_events`) and erasure — `docs/compliance/DATA_CLASSIFICATION.md`, `DATA_RETENTION.md`.
- Incident response, breach notification (72 h), BCP/DR (RPO 24 h → 1 h, RTO 4 h), restore drills — `docs/compliance/INCIDENT_RESPONSE_PLAN.md`, `BREACH_NOTIFICATION_SLA.md`, `BUSINESS_CONTINUITY_PLAN.md`, `DISASTER_RECOVERY_PLAN.md`, `RESTORE_DRILL_LOG.md`.
- IdP password/MFA standards, token lifetime, secret rotation (90 days), quarterly access review — `docs/compliance/ACCESS_CONTROL.md`.
- Policies, risk register, SoA, vendor register, AI governance — `docs/compliance/README.md`.

## Threat notes

- **Cross-user session access** (ADR-A): sessions in later specs must be keyed by `principal.subject`, never by a client-supplied id alone.
- **Compromised provisioned account**: bounded by the per-token rate limit and the audit trail; revoke at the identity provider (`check_revoked` semantics belong to the provider adapter).
- **Model key exfiltration**: the key never reaches the client; it is read only inside the adapter that talks to Gemini (future spec) and is `SecretStr`.
- **Mid-stream token expiry** (ADR-B D-8): validate once at request open; streaming endpoints inherit this.

## Operating procedures (out of code)

Secrets live in Google Cloud Secret Manager and are injected as env vars at
deploy. Credentials for the Google reviewer account are delivered out-of-band
(GGU-12). Dependency and secret scans run on every PR; findings block merge.
