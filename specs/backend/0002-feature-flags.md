# 0002 — Feature flags for endpoints

- **Area:** backend
- **Status:** Implemented
- **Ticket:** — (foundation capability requested by the TL, 2026-09-18) · **Related:** 0001, ADR-A, ADR-F, ADR-G
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-18

## 1. Problem

The showcase will ship features incrementally up to the demo. The team needs
to turn individual endpoints on and off **at runtime, without a deploy** — to
hide half-finished flows, to kill a misbehaving endpoint, and to rehearse the
demo with a fixed surface. Nothing in the backend supports that today.

## 2. Scope

**In:** persisted flags (PostgreSQL) with an in-process TTL cache; an
authenticated admin API to list and toggle flags; a `require_feature(key)`
dependency that gates any route; an environment kill-switch that wins over the
database; audit events on every change; `/v1/me/audit-events` gated as the first
consumer.
**Out:** per-user / percentage rollouts, flag scheduling, a UI (the Flutter
client may call the admin API later), multi-instance cache invalidation beyond
TTL (single instance per ADR-F D-4).

## 3. API contract

| Method & path | Auth | Request | Response | Errors |
|---|---|---|---|---|
| `GET /v1/admin/feature-flags` | Bearer + scope `admin` (+ MFA `amr` when `admin_mfa_required`) | — | `list[FeatureFlagResponse]`; audited `feature_flag.list` | `forbidden → 403` (no scope **or** no MFA) |
| `PUT /v1/admin/feature-flags/{key}` | Bearer + scope `admin` (+ MFA `amr` when `admin_mfa_required`) | `FeatureFlagUpdate{enabled, description?}` | `FeatureFlagResponse`; audited `feature_flag.update` with `target=key` | `forbidden → 403` (no scope **or** no MFA), `malformed-request → 422` |
| any gated route | as the route | — | as the route | `feature-disabled → 404` |

`key` matches `^[a-z0-9]+(\.[a-z0-9_-]+)*$` (e.g. `identity.audit`), 3–100
chars. `FeatureFlagResponse{key, enabled, description, updated_at, updated_by}`.
A disabled endpoint answers **404** `feature-disabled` so its existence is not
advertised; the body still carries `request_id`.

Resolution order for `is_enabled(key)`: `FEATURE_FLAGS_FORCE_DISABLED` env
list → cached value (TTL `FEATURE_FLAGS_CACHE_TTL_SECONDS`, default 15 s) →
database row → the gate's `default` (True unless the route says otherwise).
A database failure while reading a flag is reported and falls back to the
gate default — flags must never take the API down.

## 4. Data model & migration

`feature_flags(key varchar(100) pk, enabled bool not null, description
varchar(255), updated_by varchar(255) not null, created_at timestamptz,
updated_at timestamptz)`. Revision `0002`. No backfill: an absent row means
"use the gate default".

## 5. Security notes

Toggling is an administrative action: requires scope `admin` on the token
(ADR-B scopes), decided in the service with `principal.has_scope`, **and a
multi-factor session** (`amr` claim ∩ `MFA_METHODS`, `Principal.is_mfa`) when
`Settings.admin_mfa_required` is on — the default in production,
`AUTH_ADMIN_REQUIRE_MFA` overrides (docs/compliance/ACCESS_CONTROL.md). Every
change writes `action="feature_flag.update"` with `target=<key>` to
`audit_events` (the key can be 100 chars; `action` stays `<domain>.<verb>` in
`String(64)` — migration 0003 added `target`); every listing writes
`feature_flag.list`. Both carry the actor's subject and the request id (SOC 2
CC8.1 change management, ISO A.8.32). Reads are
unauthenticated in the sense that the gate runs before the route's own auth —
it only reveals a 404. The env kill-switch lets operators disable an endpoint
even if the database is unavailable.

## 6. Acceptance criteria

1. **AC-1** `PUT /v1/admin/feature-flags/identity.audit {enabled:false}` by an `admin` principal makes `GET /v1/me/audit-events` answer 404 `feature-disabled`; enabling it again restores 200 — without restarting the process.
2. **AC-2** A principal without the `admin` scope gets 403 `forbidden` on both admin routes; so does an `admin` without an MFA `amr` when `admin_mfa_required`; an unauthenticated caller gets 401. Listing is audited as `feature_flag.list`.
3. **AC-3** Every toggle persists a `feature_flags` row and an `audit_events` row with `action = feature_flag.update` and `target = <key>`, for any valid key length (3–100).
4. **AC-4** A key listed in `FEATURE_FLAGS_FORCE_DISABLED` is disabled regardless of the database value and cannot be enabled through the API (the response shows `enabled=false`).
5. **AC-5** Flag reads are served from cache within the TTL and refreshed after it; a database read failure falls back to the gate default and is reported through `ErrorReporter`.
6. **AC-6** Invalid keys (uppercase, spaces, >100 chars) are rejected with 422.
7. **AC-7** `make gate` stays green: 100 % branch coverage, every file ≤150 lines.

## 7. Test plan

| AC | Unit | Integration |
|---|---|---|
| AC-1 | `services/test_feature_flag_service.py`, `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_toggle_disables_and_restores_gated_endpoint` |
| AC-2 | `services/test_feature_flag_service.py::test_admin_operations_require_admin_scope`, `services/test_feature_flag_admin_mfa.py`, `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_admin_routes_require_admin_scope` |
| AC-3 | `services/test_feature_flag_service.py::test_set_flag_persists_caches_audits_and_counts` | `test_feature_flags_flow.py::test_toggle_persists_flag_and_audit_rows`, `::test_longest_valid_key_is_persisted_and_audited` |
| AC-4 | `services/test_feature_flag_service.py::test_force_disabled_wins_over_everything` | `test_feature_flags_flow.py::test_force_disabled_env_wins_over_database` |
| AC-5 | `services/test_feature_flag_cache.py`, `services/test_feature_flag_service.py::test_read_failure_falls_back_to_default_and_reports` | — |
| AC-6 | `schemas` validation via `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_invalid_key_is_422` |
| AC-7 | gate | gate |

Mutation checks: gate dependency disabled → AC-1 tests red (performed 2026-09-18); MFA branch of `_require_admin` disabled → `test_feature_flag_admin_mfa.py::test_admin_without_mfa_is_forbidden_when_mfa_required` red (performed 2026-09-19).

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Should a disabled endpoint answer 404 or 503? | Lautaro | 404 `feature-disabled` (does not advertise the route) |
| OD-2 | Cache TTL for a multi-instance future | Lautaro | **Resolved 2026-09-20 (GGU-83).** 15 s, and `max_instances` is pinned to 1, so there is one cache and no cross-instance propagation window — a toggle takes effect within the TTL. The `FEATURE_FLAGS_FORCE_DISABLED` kill-switch never depended on this: it is an environment variable read at startup on every instance. Re-opens with spec `backend/0001` OD-2, on the same condition (any environment needing `max_instances > 1`); the answer then is Redis pub/sub or an accepted, documented TTL window |
| OD-3 | Who holds the `admin` scope in Firebase tokens | Pato / Lautaro | custom claim `roles: ["admin"]` set with the Admin SDK on provisioned operator accounts |

## 9. Rollout & observability

Flags default to enabled, so shipping this spec changes no behaviour. Toggles
appear in `audit_events` and as `feature_flag.toggled{key,enabled}` metrics;
cache refreshes and read failures are logged with the key.
