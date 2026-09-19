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
docker compose up --build
```

- API: <http://localhost:8000> · OpenAPI: <http://localhost:8000/docs>
- Liveness: `GET /healthz` · Readiness: `GET /readyz` · Who am I: `GET /v1/me`
- Feature flags: `GET/PUT /v1/admin/feature-flags[/{key}]` (scope `admin`) — see [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md)

Without Docker:

```bash
cd backend
uv sync                                  # installs the locked toolchain
cp env.example .env                     # fill the values, never commit .env
uv run alembic upgrade head              # needs DATABASE_URL to point at Postgres
uv run uvicorn app.main:app --reload
```

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
└── scripts/            gate helpers (file budget); `make audit` runs pip-audit
```

Every file stays under **150 lines** (`scripts/check_file_budget.py` fails the
gate otherwise). Controllers never contain logic; services never import FastAPI;
repositories are the only code that touches SQLAlchemy sessions.

## Documentation index

| Doc | What it answers |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, dependency direction, patterns, how to add a feature |
| [docs/SECURITY.md](docs/SECURITY.md) | Controls mapped to SOC 2 TSC and ISO/IEC 27001 Annex A |
| [docs/AUTH.md](docs/AUTH.md) | Bearer-token auth, provider registry, adding OAuth / SSO |
| [docs/TESTING.md](docs/TESTING.md) | Unit vs integration, fixtures, the 100 % coverage gate |
| [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) | Structured logs, request ids, Sentry, metrics |
| [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md) | Enable/disable endpoints at runtime, admin API, kill-switch |
| [../specs/](../specs/) | Spec-driven development: one spec per feature |

License: Apache-2.0 (see repository root).
