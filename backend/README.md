# finance-a2ui backend

FastAPI service for the Somnio × Google **A2UI finance showcase**. This is the
foundation release: no product features yet, only the paved path every feature
will follow (layers, auth, persistence, observability, security controls, 100 %
tests, spec-driven workflow).

Read [`CLAUDE.md`](CLAUDE.md) first if you are working with an AI agent — it is
the operating manual. Human-oriented docs live in [`docs/`](docs/).

## Run

```bash
# from the repository root — Postgres + backend, with hot reload
cp backend/env.example backend/.env      # once; compose loads it via env_file (never commit .env)
docker compose up --build
```

Compose only sets the topology keys (`DATABASE_URL` → `db`, `PUBLIC_BASE_URL`,
`CORS_ALLOWED_ORIGINS`, `UVICORN_EXTRA_ARGS`); everything else — credentials
included — is read from `backend/.env`.

- API: <http://localhost:8000> · OpenAPI: <http://localhost:8000/docs>
- Liveness: `GET /healthz` · Readiness: `GET /readyz` · Who am I: `GET /v1/me`
- Feature flags: `GET/PUT /v1/admin/feature-flags[/{key}]` (scope `admin`) — see [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md)
- View catalog: `GET /v1/views` — every projection the backend can render, with its options schema and an example payload
- Portfolio projections: `GET /v1/portfolios/current/views?view=<id>&view=<id>` — repeat `view` for up to four projections in one request; omit it and a documented selection rule picks one. See [ADR-K](../docs/adr/ADR-K-response-shaping.md) and [spec 0005](../specs/backend/0005-presentation-layer.md)
- Conversation sessions: `POST/GET /v1/sessions`, `GET/DELETE /v1/sessions/{id}`,
  `POST/GET /v1/sessions/{id}/messages` — owned by the token's subject, flag
  `sessions.api` ([spec 0004](../specs/backend/0004-session-identity.md))

Without Docker:

```bash
cd backend
uv sync                                  # installs the locked toolchain
cp env.example .env                     # fill the values, never commit .env
uv run alembic upgrade head              # needs DATABASE_URL to point at Postgres
uv run uvicorn app.main:app --reload
```

## The demo portfolio — which symbol to ask about

`src/app/domain/` holds a curated, entirely simulated portfolio (spec
[`0003-portfolio-domain.md`](../specs/backend/0003-portfolio-domain.md)) and is
the backend's **single source of price**. It is seeded per subject at a fixed
`as_of`, so the numbers never move between two questions in the same session.

Three cases are built into the seed on purpose. A demo driver who has never
seen the data should ask about these symbols:

| Flow | Symbol | Why that one |
|---|---|---|
| **Tax-lot flow** | **BTC** | Two lots straddling the 1-year line — `lot-btc-01` at 367 days (long-term) and `lot-btc-02` at 363 days (short-term, two days inside it). Selling picks a side. |
| **Attribution story** | **ETH** (and **LINK**) | The losers. ETH is roughly −15 % against its blended cost basis while BTC and SOL are up, so attribution has something to explain instead of a wall of green. |
| **Order / payoff** | **SOL** | 60 units bought, 20 sold, 40 still open — a simulated sale has a real history behind it, and the remaining lot is single-term so the payoff is easy to follow. |

The boundary rule the tax flow depends on: a lot is **long-term only beyond 365
days held** — the anniversary itself is still short-term
(`src/app/domain/terms.py`). Price history is a deterministic 90-day daily
series per symbol whose last point is exactly the current price.

## Verify — a change is not done without this

```bash
cd backend && make gate      # ruff · format · basedpyright · file budget · pytest 100 %
```

`make gate` is exactly what CI runs (`.claude/ship-gate.json` lists the same
commands). Integration tests start a throwaway PostgreSQL through
[testcontainers](https://testcontainers-python.readthedocs.io/) — Docker must be
running. Set `TEST_DATABASE_URL` to reuse an existing database instead.

## Layout

```
backend/
├── src/app/
│   ├── api/            controllers (routers), dependencies, middleware, error handlers
│   ├── services/       use cases — the only place with business rules
│   ├── repositories/   persistence access, one per aggregate
│   ├── models/         SQLAlchemy ORM entities
│   ├── schemas/        pydantic request / response DTOs
│   ├── domain/         the simulated portfolio: entities, invariants, seed, prices
│   ├── auth/           token verification providers (JWT, OIDC/SSO) behind a Protocol
│   ├── infra/          adapters: database engine/session, telemetry (Sentry)
│   ├── core/           settings, error hierarchy, logging, shared Protocols
│   ├── helpers/        tiny pure utilities
│   ├── bootstrap.py    composition root — the ONLY place that wires concrete classes
│   └── main.py         ASGI entry point
├── alembic/            migrations
├── tests/unit/         no I/O, fakes only
├── tests/integration/  real PostgreSQL via testcontainers
├── docs/               architecture, security (SOC 2 / ISO 27001), testing, auth, observability
└── scripts/            gate helpers (file budget); `make audit` runs pip-audit, `make purge-audit` runs `app.jobs.purge_audit`
```

Every file stays under **150 lines** (`scripts/check_file_budget.py` fails the
gate otherwise). Controllers never contain logic; services never import FastAPI;
repositories are the only code that touches SQLAlchemy sessions.

## Documentation index

| Doc | What it answers |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, dependency direction, patterns, how to add a feature |
| [docs/ADDING_AN_ENDPOINT.md](docs/ADDING_AN_ENDPOINT.md) | Where routes live, the layer-by-layer recipe, controller template, tests per layer |
| [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md) | Runtime endpoint switches: `require_feature`, admin API, kill-switch |
| [docs/SECURITY.md](docs/SECURITY.md) | Controls mapped to SOC 2 TSC and ISO/IEC 27001 Annex A |
| [docs/AUTH.md](docs/AUTH.md) | Bearer-token auth, provider registry, adding OAuth / SSO |
| [docs/TESTING.md](docs/TESTING.md) | Unit vs integration, fixtures, the 100 % coverage gate |
| [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) | Structured logs, request ids, Sentry, metrics |
| [../specs/](../specs/) | Spec-driven development: one spec per feature |

License: Apache-2.0 (see repository root).
