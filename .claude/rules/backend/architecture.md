---
description: Backend layering and file pattern — controllers call services, services own rules, repositories own SQLAlchemy, 150-line file budget, composition root in bootstrap.py. Loads when touching backend/src or backend/tests.
paths:
  - "backend/src/**/*.py"
  - "backend/tests/**/*.py"
alwaysApply: false
---

# Backend architecture rules

Every file in `backend/src/app` belongs to exactly one layer and follows that layer's template. When adding code, copy the closest existing file of the same layer and keep its shape.

## Layers (dependencies point inward only)

| Layer | Folder | May import | Must not import |
|---|---|---|---|
| Controller | `api/v1/` | `api.deps`, `schemas`, `services` (types) | `repositories`, `models`, `sqlalchemy` |
| Dependencies | `api/deps.py` | everything below | — |
| Service | `services/` | `schemas`, `repositories`, `models`, `core` (incl. `core.principal`) | `fastapi`, `starlette`, `sqlalchemy`, `auth.providers` |
| Repository | `repositories/` | `models`, `core.errors`, `sqlalchemy` | `services`, `api` |
| Model | `models/` | `models.base`, `sqlalchemy` | anything else in `app` |
| Schema | `schemas/` | `pydantic` | `models`, `services` |
| Adapter | `infra/`, `auth/providers/` | `core`, third-party SDKs | `services`, `api` |
| Core | `core/` | stdlib, `pydantic` | any framework |

`bootstrap.py` is the only module that instantiates `infra`/`auth.providers` classes. Tests may build a `Container` by hand.

## Templates

- **Controller**: `router = APIRouter(prefix=..., tags=[...])`; each handler has a `summary`, a `response_model`, resolves `Depends`, calls one service method, returns the DTO. No branching, no try/except, no `HTTPException`.
- **Service**: a class with an `__init__` receiving collaborators (repositories, other services, Protocols) and small async methods returning pydantic DTOs or ORM entities. Business rules and error raising live here.
- **Repository**: subclass `BaseRepository[Model]`, set `model = ...`, add named queries. Wrap `SQLAlchemyError` in `DependencyUnavailableError` (`raise ... from exc`).
- **Model**: `class X(TimestampMixin, Base)` with `__tablename__`, explicit `String(n)` lengths, indexes declared in `__table_args__`. One table per file, plus an Alembic revision.
- **Schema**: `ConfigDict(frozen=True)`; `from_attributes=True` only when built from ORM rows.
- **Provider / adapter**: implement a `Protocol` from `core/protocols.py`; expose a `name`; translate SDK exceptions to `AppError` subclasses.

## Hard constraints (enforced by the gate)

- Max **150 lines per file** — `scripts/check_file_budget.py`. Split by responsibility.
- 100 % branch coverage of `src/app`; `fail_under = 100` is not negotiable per PR.
- basedpyright strict, ruff `E F W I D UP B S N ANN RUF` — no bare `# noqa`, no bare `# type: ignore`.
- Public functions have Google-style docstrings; signatures fully annotated; keyword-only args for flags and configuration.
- `datetime.now()` only through the injected `Clock`; `os.environ` only in `core/config.py` and `alembic/env.py`.

## When a request does not fit

If a feature seems to need a controller with logic, a 300-line service or a service importing SQLAlchemy, the design is wrong, not the rule: extract a helper module, a second service, or a repository query. Record the decision in the feature spec under `specs/backend/`.
