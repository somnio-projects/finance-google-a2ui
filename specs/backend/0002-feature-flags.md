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
database; audit events on every change; `/v1/me/audit` gated as the first
consumer.
**Out:** per-user / percentage rollouts, flag scheduling, a UI (the Flutter
client may call the admin API later), multi-instance cache invalidation beyond
TTL (single instance per ADR-F D-4).

## 3. API contract

| Method & path | Auth | Request | Response | Errors |
|---|---|---|---|---|
| `GET /v1/admin/feature-flags` | Bearer + scope `admin` | — | `list[FeatureFlagResponse]` | `forbidden → 403` |
| `PUT /v1/admin/feature-flags/{key}` | Bearer + scope `admin` | `FeatureFlagUpdate{enabled, description?}` | `FeatureFlagResponse` | `forbidden → 403`, `malformed-request → 422` |
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
(ADR-B scopes), decided in the service with `principal.has_scope`. Every
change writes `feature_flag.update` to `audit_events` with the actor's subject
and the request id (SOC 2 CC8.1 change management, ISO A.8.32). Reads are
unauthenticated in the sense that the gate runs before the route's own auth —
it only reveals a 404. The env kill-switch lets operators disable an endpoint
even if the database is unavailable.

## 6. Acceptance criteria

1. **AC-1** `PUT /v1/admin/feature-flags/identity.audit {enabled:false}` by an `admin` principal makes `GET /v1/me/audit` answer 404 `feature-disabled`; enabling it again restores 200 — without restarting the process.
2. **AC-2** A principal without the `admin` scope gets 403 `forbidden` on both admin routes; an unauthenticated caller gets 401.
3. **AC-3** Every toggle persists a `feature_flags` row and an `audit_events` row with action `feature_flag.update`.
4. **AC-4** A key listed in `FEATURE_FLAGS_FORCE_DISABLED` is disabled regardless of the database value and cannot be enabled through the API (the response shows `enabled=false`).
5. **AC-5** Flag reads are served from cache within the TTL and refreshed after it; a database read failure falls back to the gate default and is reported through `ErrorReporter`.
6. **AC-6** Invalid keys (uppercase, spaces, >100 chars) are rejected with 422.
7. **AC-7** `make gate` stays green: 100 % branch coverage, every file ≤150 lines.

## 7. Test plan

| AC | Unit | Integration |
|---|---|---|
| AC-1 | `services/test_feature_flag_service.py`, `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_toggle_disables_and_restores_gated_endpoint` |
| AC-2 | `services/test_feature_flag_service.py::test_*_requires_admin_scope`, `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_admin_routes_require_admin_scope` |
| AC-3 | `services/test_feature_flag_service.py::test_set_records_audit_event` | `test_feature_flags_flow.py::test_toggle_persists_flag_and_audit_rows` |
| AC-4 | `services/test_feature_flag_service.py::test_force_disabled_wins` | `test_feature_flags_flow.py::test_force_disabled_env_wins_over_database` |
| AC-5 | `services/test_feature_flag_cache.py`, `services/test_feature_flag_service.py::test_read_failure_falls_back_to_default` | — |
| AC-6 | `schemas` validation via `api/test_feature_gate.py` | `test_feature_flags_flow.py::test_invalid_key_is_422` |
| AC-7 | gate | gate |

Mutation checks: gate dependency disabled → AC-1 tests red (performed).

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Should a disabled endpoint answer 404 or 503? | Lautaro | 404 `feature-disabled` (does not advertise the route) |
| OD-2 | Cache TTL for a multi-instance future | Lautaro | 15 s; move to Redis pub/sub if `max-instances > 1` |
| OD-3 | Who holds the `admin` scope in Firebase tokens | Pato / Lautaro | custom claim `roles: ["admin"]` set with the Admin SDK on provisioned operator accounts |

## 9. Rollout & observability

Flags default to enabled, so shipping this spec changes no behaviour. Toggles
appear in `audit_events` and as `feature_flag.toggled{key,enabled}` metrics;
cache refreshes and read failures are logged with the key.
