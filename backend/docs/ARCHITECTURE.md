# Architecture

## Purpose

The backend is the host for the A2UI agent and the source of truth for the
simulated portfolio. This foundation release ships the *shape* every feature
must follow; the agent and the finance domain are added on top of it by later
specs (`specs/backend/`).

## Layers

```
            HTTP
             │
   ┌─────────▼──────────┐   api/          controllers (routers), Depends providers,
   │        API         │                 middleware, RFC 9457 error handlers
   └─────────┬──────────┘
             │ calls one method, passes DTOs / Principal
   ┌─────────▼──────────┐   services/     use cases, business rules, authorization by scope
   │      Services      │
   └─────────┬──────────┘
             │ entities in, entities out
   ┌─────────▼──────────┐   repositories/ queries over one aggregate, SQLAlchemy only here
   │    Repositories    │
   └─────────┬──────────┘
             │
   ┌─────────▼──────────┐   models/       ORM entities (Base + TimestampMixin)
   │       Models       │
   └────────────────────┘

   core/        Settings · AppError hierarchy · Protocols · logging   (framework-free)
   schemas/     pydantic DTOs crossing the HTTP boundary
   auth/        Principal · claim mapping · providers (jwt, oidc) · registry
   infra/       adapters implementing core Protocols: db engine/session, telemetry
   bootstrap.py composition root: builds Container, installs middleware, mounts routers
```

Dependencies point downward/inward only. `bootstrap.py` is the only module
allowed to import `infra` and `auth.providers` concretes; everything else
depends on the Protocols in `core/protocols.py` (`Clock`, `TokenVerifier`,
`ErrorReporter`, `ReadinessProbe`).

## Patterns in use

| Pattern | Where | Why |
|---|---|---|
| Composition root / manual DI | `bootstrap.build_container`, `api/deps.py` | One place to see the object graph; tests inject doubles |
| Ports & adapters (Protocols) | `core/protocols.py` ↔ `infra/`, `auth/providers/` | Sentry, Postgres, identity providers are swappable |
| Repository + generic base | `repositories/base.py` | Uniform CRUD, infrastructure errors translated once |
| Unit of work | `infra/db/session.py::session_scope` | Commit/rollback per request, never in services |
| Strategy + registry | `auth/registry.py` | Provider selected by configuration, extension without modification |
| Null object | `infra/telemetry/null_reporter.py` | Call sites never check whether telemetry is configured |
| Typed errors → problem details | `core/errors.py`, `api/errors.py` | Clients branch on `type`, never on text |
| Middleware chain | `bootstrap._install_middleware` | Cross-cutting HTTP concerns outside controllers |

## Request lifecycle

1. `RequestIdMiddleware` mints/echoes `X-Request-ID`, binds it to structlog.
2. `SecurityHeadersMiddleware`, `TrustedHostMiddleware`, CORS, `BodyLimitMiddleware`, `RateLimitMiddleware` run in that order (outer → inner).
3. Route → `Depends` resolution (`api/deps.py`): container → session (unit of work) → services → `PrincipalDep` (auth).
4. Controller calls one service method; service uses repositories; repositories use the request session.
5. `session_scope` commits on success, rolls back on exception; error handlers render `AppError`s as `application/problem+json`.

## Adding a feature

1. Spec in `specs/backend/` (see `/spec`).
2. Alembic revision + `models/<entity>.py` (+ export in `models/__init__.py`).
3. `schemas/<feature>.py` DTOs.
4. `repositories/<entity>_repository.py` subclassing `BaseRepository`.
5. `services/<feature>_service.py` with the use cases.
6. `api/v1/<feature>.py` controller + providers in `api/deps.py` + `include_router` in `api/router.py`.
7. Tests beside each layer; integration test for the HTTP flow.

Each file ≤150 lines. If a step needs more, the responsibility is too broad —
split (e.g. `pricing_service.py` + `pricing_rules.py`).

## Where the A2UI agent will go (OD-1 of spec 0001)

Default decision: mount the A2A Starlette application under this FastAPI app
(`app.mount("/a2a", ...)`) so it sits behind the same auth middleware,
container and telemetry. The ADK runner and tools become services/adapters in
this layout; the portfolio domain is a set of models + repositories + services.
