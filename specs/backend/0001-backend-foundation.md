# 0001 — Backend foundation (FastAPI service)

- **Area:** backend
- **Status:** Implemented
- **Ticket:** GGU-3, GGU-45, GGU-46 (re-baselined: the ADK sample is replaced) · **Related:** ADR-A, ADR-B, ADR-F, ADR-G, ADR-H (PR #1)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-18

## 1. Problem

`backend_python/` was Google's A2A crypto sample: five flat modules, one
hardcoded `user_id`, three disjoint session stores, no tests, no tooling, no
auth. The showcase needs a backend that other developers (and their Claude
sessions) can extend safely in days: a fixed layering, 100 % tests, security
controls acceptable under SOC 2 / ISO 27001, Postgres persistence and pluggable
authentication (Firebase/OIDC today, other SSO later).

## 2. Scope

**In:** `backend/` FastAPI service skeleton with the full paved path — layers,
composition root, settings, error contract, auth providers (HS256 + OIDC/JWKS),
Postgres + Alembic, audit trail, security middleware, Sentry adapter, health
endpoints, `/v1/me`, Docker + compose, CI gate, harness (rules, hooks,
commands, reviewer, specs).
**Out:** the A2UI agent / A2A transport (GGU-3 follow-up spec), portfolio
domain (GGU-5), Flutter client wiring (GGU-2), Cloud Run deploy (GGU-29).

## 3. API contract

| Method & path | Auth | Response | Errors |
|---|---|---|---|
| `GET /health` | none | `HealthResponse{status:"ok", version}` | — |
| `GET /readyz` | none | `ReadinessResponse{status, dependencies[]}` | `503` when degraded |
| `GET /v1/me` | Bearer | `MeResponse{subject, provider, email, scopes[]}` | `auth/missing-token`, `auth/invalid-token`, `auth/expired-token` → 401 |
| `GET /v1/me/audit-events?limit=1..100` | Bearer | `list[AuditEventResponse]` | `malformed-request → 422`, auth codes |
| any | — | — | `rate-limited → 429`, `payload-too-large → 413`, `internal → 500` |

All errors are RFC 9457 `application/problem+json` with
`type = https://errors.finance-a2ui/<code>`, `instance` and `request_id` —
including the 413/429 produced by middleware. Known exception: Starlette's
`TrustedHostMiddleware` answers a plain-text 400 for an unlisted `Host` (it
runs before our handlers); accepted for the foundation, tracked as OD-4.

## 4. Data model & migration

`audit_events(id uuid pk, created_at timestamptz, subject varchar(255),
provider varchar(32), action varchar(64), token_fingerprint varchar(64),
request_id varchar(64))`, index `(subject, created_at)`. Revision `0001`.
Retention: unbounded for the review window; revisit before production data.

## 5. Security notes

Bearer ID tokens only (ADR-B); `iss`/`aud`/`exp`/`iat`/`sub` required; OIDC
keys via JWKS with 1 h cache. No allow-list — compensating per-token rate
limit (ADR-G D-7). Audit event `identity.read` per `/v1/me`. Security
headers, `TrustedHost`, CORS allow-list, 1 MiB body limit. Secrets only via
`SecretStr` settings; Sentry with `send_default_pii=False`. Non-root,
read-only container. Full mapping: `backend/docs/SECURITY.md`.

## 6. Acceptance criteria

1. **AC-1** `make gate` is green from a clean clone: ruff, format, basedpyright strict, file budget (≤150 lines), pytest with 100 % branch coverage.
2. **AC-2** `/health` and `/readyz` are unauthenticated; `/readyz` returns 503 with `status: degraded` when PostgreSQL is unreachable and 200 `ready` otherwise.
3. **AC-3** `/v1/me` without a token → 401 `auth/missing-token`; garbage/wrong-secret/wrong-audience/wrong-issuer → 401 `auth/invalid-token`; expired → 401 `auth/expired-token`; none of the bodies contain library text or stack traces.
4. **AC-4** A valid token → 200 with subject/provider/email/scopes and one `audit_events` row whose `request_id` equals the response `X-Request-ID`; the token never appears in responses or logs.
5. **AC-5** OIDC provider verifies RS256 tokens against a JWKS document, caches keys for the TTL and rejects unknown `kid`/issuer.
6. **AC-6** Every response carries the security headers; HSTS only in production; docs hidden in production.
7. **AC-7** Exceeding `RATE_LIMIT_PER_MINUTE` returns 429 with `Retry-After`, keyed per token (else per IP), health paths exempt.
8. **AC-8** Unhandled exceptions are reported through `ErrorReporter` and answered with the generic `internal` problem.
9. **AC-9** `docker compose up --build` starts Postgres + backend; migrations run on start; the container runs as uid 10001 read-only.
10. **AC-10** Missing required settings crash at startup naming the variable.

## 7. Test plan

| AC | Unit | Integration |
|---|---|---|
| AC-1 | whole suite | whole suite |
| AC-2 | `api/test_health_endpoints.py`, `services/test_health_service.py`, `infra/test_db.py` | `test_identity_flow.py::test_readyz_is_ready_with_a_live_database` |
| AC-3 | `auth/test_jwt_provider.py`, `api/test_identity_auth.py`, `services/test_auth_service.py` | `test_identity_flow.py::test_expired_token_is_rejected_with_distinguishable_code` |
| AC-4 | `services/test_audit_and_identity.py` | `test_identity_flow.py::test_me_returns_identity_and_records_audit_trail`, `test_audit_trail_is_isolated_per_subject`, `test_repositories.py` |
| AC-5 | `auth/test_oidc_provider.py`, `auth/test_jwks.py`, `auth/test_registry.py` | — |
| AC-6, AC-7 | `api/test_middleware.py` | — |
| AC-8 | `api/test_error_handlers.py`, `infra/test_telemetry.py` | — |
| AC-9 | — | manual: `docker compose up --build`, `curl /health` (recorded in PR) |
| AC-10 | `core/test_config.py` | — |

Mutation checks: auth middleware and rate limiter — yes (performed before PR).

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Where does the A2UI/A2A agent live — mounted inside this FastAPI app or a sibling service? | Lautaro + Mario | Mount the A2A Starlette app under this FastAPI app behind the same auth middleware (one deployable) |
| OD-2 | Rate-limit backend for multi-instance deploys | Lautaro | **Resolved 2026-09-20 (GGU-83) — see below.** In-memory, with `max_instances` pinned to 1 so the documented limit is the enforced one. Re-opens on the condition named below, not on a date. |
| OD-3 | Firebase JWKS URL / issuer values for `finance-a2ui` | Pato / Lautaro | `oidc` provider with Google's securetoken JWKS; issuer `https://securetoken.google.com/finance-a2ui`, audience `finance-a2ui` |
| OD-4 | `TrustedHostMiddleware` 400 is plain text, not problem+json | Lautaro | Accept for Epic 0; replace with a custom Host check returning problem+json when the client needs to parse it |
| OD-5 | `FORWARDED_ALLOW_IPS` defaults to `*` (Cloud Run's LB is the only ingress) | Lautaro | Keep `*` on Cloud Run; set the proxy CIDR anywhere clients can reach uvicorn directly |

### OD-2 resolved — 2026-09-20 (GGU-83)

OD-2 was written as *"Redis adapter when `max-instances > 1`"*. That condition became **true** when
dev was scaled to `1/2` for the cold-start budget, and nothing noticed: the scaling change was made
on cost grounds and the constraint it violated lived in another document. The per-principal limit was
silently twice what `backend/docs/SECURITY.md` documents. **A condition nobody evaluates is not a
condition** — which is why the resolution below is enforced by a test rather than by a sentence.

**Resolution (TL, Option B):** keep the in-memory limiter and pin the instance count instead.
`infra/main.tf` derives `max_instances = 1` and every `infra/environments/*.tfvars` sets 1, which
makes the documented limit the enforced one. This does not make the limiter correct; it makes the
configuration match what the limiter can do.

**The condition under which OD-2 re-opens** — any one of these, not a date:

1. Any environment needs `max_instances > 1` (load, availability, or a rollout strategy that runs
   two revisions at once). The pin is the only thing holding the limit, so raising it re-opens this.
2. The limiter has to survive a revision restart, or the limit must be shared with any other
   process — a second service, a worker, or a job.
3. The per-principal limit becomes a hard commitment to a third party rather than the compensating
   control [ADR-G](../../docs/adr/ADR-G-secret-handling.md) D-7 describes.

When it re-opens, the fix is the one this OD always named: a shared backing store (Memorystore was
Option A, costed on GGU-83) behind `FixedWindowLimiter`, which is a small class precisely so the swap
stays contained. The feature-flag cache takes the same treatment or keeps its TTL window, documented.

**What holds it shut meanwhile:** `infra/scripts/tests/test_rate_limit_ceiling.sh`
(`infra.rate-limit-ceiling` in `.claude/ship-gate.json`) compares the Terraform ceiling, the
configured default and the two numbers in `backend/docs/SECURITY.md`, and fails naming both sides.
Condition 1 above cannot be met silently: raising the ceiling turns the gate red and the message
points back here. See [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md) **D-9**.

## 9. Rollout & observability

Local via compose. Startup logs the public base URL; each request logs with
`request_id`; auth accept/reject counters go to the reporter; Sentry enabled by
setting `SENTRY_DSN`.
