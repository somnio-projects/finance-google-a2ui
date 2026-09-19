# NNNN — <Feature name>

- **Area:** backend | client
- **Status:** Draft
- **Ticket:** GGU-n · **Related specs / ADRs:** …
- **Owner:** <person> · **Date:** YYYY-MM-DD

## 1. Problem

What is missing or wrong today, for whom, and why it matters for the showcase.
One paragraph; link evidence (ticket, issue, code path).

## 2. Scope

**In:** bullet list of what this spec delivers.
**Out:** what is explicitly deferred, with the spec/ticket that will own it.

## 3. API contract

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `GET /v1/…` | Bearer | — | `XResponse` | `not-found → 404` |

DTO shapes (pydantic) with field constraints. Problem-details codes follow
`https://errors.finance-a2ui/<code>`.

## 4. Data model & migration

Tables/columns added or changed, indexes, retention. Name the Alembic
revision (`NNNN_<slug>`). State whether existing rows are affected.

## 5. Security notes

Authentication and authorization (scopes), audit events written
(`<domain>.<verb>`), personal data handled and its retention, rate limits,
anything that changes the threat model. Map to `backend/docs/SECURITY.md`.

## 6. Acceptance criteria

1. **AC-1** — observable, testable statement.
2. **AC-2** — …

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/services/test_x.py::test_…` | `tests/integration/test_x_flow.py::test_…` |

Mutation checks required (auth / rate limit / error masking): yes/no.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | … | … | … |

## 9. Rollout & observability

Feature flags, migrations order, metrics/log events added, Sentry expectations.
