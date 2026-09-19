# Feature flags (spec 0002)

Turn endpoints on and off at runtime, without a deploy.

## How it works

```
request ──► require_feature("identity.audit") ──► FeatureFlagService.is_enabled
                                                      │ 1. FEATURE_FLAGS_FORCE_DISABLED (env)  → False
                                                      │ 2. in-process cache (TTL 15 s)         → cached
                                                      │ 3. feature_flags table                 → row.enabled
                                                      └ 4. gate default (True unless stated)   → default
```

- A disabled flag makes the route answer **404 `feature-disabled`** (problem+json
  with `request_id`) before the route body or its own auth dependency runs.
- Flags are stored in PostgreSQL (`feature_flags`), cached per process for
  `FEATURE_FLAGS_CACHE_TTL_SECONDS` (default 15) and refreshed immediately in
  the process that toggles them. Other instances pick the change up within the
  TTL (single instance today, ADR-F D-4).
- `FEATURE_FLAGS_FORCE_DISABLED=identity.audit,orders.submit` is the
  operator kill-switch: it wins over the database and over the API, and works
  even when the database is down.
- A database failure while reading a flag is reported to the `ErrorReporter`
  and the gate falls back to its default — flags never take the API down.

## Gating a route

```python
from app.api.feature_gate import require_feature

@router.get("/orders", dependencies=[require_feature("orders.read")])
async def list_orders(...): ...

@router.post("/orders", dependencies=[require_feature("orders.submit", default=False)])
async def submit_order(...): ...   # dark-launched: off until an admin enables it
```

Key convention: lowercase dotted segments, `<domain>.<capability>`
(`identity.audit`, `orders.submit`). Keys are validated with
`^[a-z0-9]+(\.[a-z0-9_-]+)*$`, 3–100 chars.

## Admin API (scope `admin`)

| Method & path | Body | Result |
|---|---|---|
| `GET /v1/admin/feature-flags` | — | every persisted flag |
| `PUT /v1/admin/feature-flags/{key}` | `{"enabled": false, "description": "why"}` | upserts, refreshes the cache, audits |

Both require a bearer token whose scopes/roles include `admin` — and, in
production (or when `AUTH_ADMIN_REQUIRE_MFA=true`), an `amr` claim proving a
second factor (see `docs/AUTH.md`, "Authorization"). The scope may come from
`scope: "admin"`, `scp: ["admin"]` or `roles: ["admin"]`; anyone else gets
403 `forbidden`. Every change writes `feature_flag.update` (with `target` =
the key) to `audit_events` with the actor's subject and the request id; every
listing writes `feature_flag.list`. Toggles also emit the
`feature_flag.toggled{key,enabled}` metric.

```bash
TOKEN=...   # admin token
curl -X PUT http://localhost:8000/v1/admin/feature-flags/identity.audit \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"enabled": false, "description": "hide during rehearsal"}'
curl http://localhost:8000/v1/me/audit -H "Authorization: Bearer $USER_TOKEN"   # -> 404 feature-disabled
```

## Adding a flag

1. Pick the key and the default (`True` for existing behaviour, `False` for a dark launch).
2. Add `dependencies=[require_feature("<key>", default=...)]` to the route.
3. Document the key in the feature's spec under *Rollout*.
4. Tests: one unit test with the fake service (see `tests/unit/api/test_feature_gate.py`) and, if the flow matters, an integration toggle test.

## Files

`models/feature_flag.py` · `alembic/versions/20260918_0002_feature_flags.py` ·
`schemas/feature_flags.py` · `repositories/feature_flag_repository.py` ·
`services/feature_flag_cache.py` · `services/feature_flag_service.py` ·
`api/feature_gate.py` · `api/v1/feature_flags.py` · settings
`feature_flags_cache_ttl_seconds`, `feature_flags_force_disabled`.
