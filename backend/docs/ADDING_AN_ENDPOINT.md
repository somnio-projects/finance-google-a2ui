# Adding an endpoint

The recipe every new route follows. `/feature <GGU-n description>` runs it
end to end with the harness; this page is the human-readable version so a
reviewer can check that nothing was skipped.

## Where routes live

```
src/app/api/router.py        ← ONE registration point: include_router(<domain>.router)
src/app/api/v1/<domain>.py   ← one controller module per domain (health, identity, feature_flags, …)
src/app/api/deps.py          ← one `get_<thing>_service()` provider per service
src/app/api/feature_gate.py  ← require_feature("<domain>.<capability>") for switchable routes
```

A controller module owns exactly one `APIRouter` (prefix + tags) and is the
only place that mentions HTTP paths. Nothing else in `src/app` knows a URL.

## Steps (layer order — each with its tests)

1. **Spec** — `specs/backend/NNNN-<feature>.md` from `specs/TEMPLATE.md`;
   the API contract table lists path, DTOs and error codes. Approved before code.
2. **Migration + model** (only if persistence changes) —
   `alembic revision -m "<table>"` under `alembic/versions/`, one model file
   under `models/` (`TimestampMixin, Base`, explicit `String(n)`, indexes in
   `__table_args__`).
3. **Schemas** — request/response DTOs in `schemas/<domain>.py`
   (`ConfigDict(frozen=True)`, bounds on every field: `max_length`, `ge`, …).
4. **Repository** — `repositories/<domain>_repository.py`, subclass
   `BaseRepository[Model]`, named queries only, wrap `(SQLAlchemyError, OSError)`
   in `DependencyUnavailableError`.
5. **Service** — `services/<domain>_service.py`: collaborators in `__init__`,
   small async methods returning DTOs, business rules and `AppError` raising
   here. Authorization via `principal.has_scope(...)`. Audit through
   `AuditService.record("<domain>.<verb>", …)` for security-relevant actions.
6. **Provider** — `api/deps.py`: `get_<domain>_service(...)` composing the
   repository from `SessionDep` and the shared collaborators from the
   `Container`.
7. **Controller** — `api/v1/<domain>.py` (template below).
8. **Register** — `api/router.py`: `api_router.include_router(<domain>.router)`.
9. **Docs** — `README.md` endpoint list, `docs/*.md` that describe the
   behaviour, `env.example` for new settings.
10. **Gate** — `make gate` green (100 % branch coverage includes the new
    controller, service, repository and every error path), then
    `backend-reviewer`, then the PR with `Spec:` and `Test decision:` lines,
    then the `.claude/harness-log.md` entry.

## Controller template

```python
"""<Domain> controllers — <one line on what the routes do> (spec NNNN)."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import PrincipalDep, get_<domain>_service
from app.api.feature_gate import require_feature
from app.schemas.<domain> import <Thing>Response
from app.services.<domain>_service import <Domain>Service

router = APIRouter(prefix="/v1/<domain>", tags=["<domain>"])
<Domain>Dep = Annotated[<Domain>Service, Depends(get_<domain>_service)]


@router.get(
    "/{thing_id}",
    response_model=<Thing>Response,
    summary="<Imperative summary shown in OpenAPI>",
    dependencies=[require_feature("<domain>.<capability>", default=False)],
)
async def read_thing(
    thing_id: str, principal: PrincipalDep, service: <Domain>Dep
) -> <Thing>Response:
    """<One sentence: what the caller gets.> Spec NNNN AC-<n>."""
    return await service.read(principal, thing_id)


__all__ = ["router"]
```

The operation must also carry `operation_id`, `description` and a full
`responses=` map built with `app.api.openapi.problem_responses(...)` — see
`.claude/rules/backend/api-design.md` for the complete contract.

Rules the reviewer checks on a controller:

- resolves `Depends`, calls **one** service method, returns the DTO — no
  branching, no `try/except`, no `HTTPException`, no SQLAlchemy;
- `PrincipalDep` on every route unless the spec marks it public (only the
  health probes are public today);
- `summary=` and `response_model=` on every operation; the docstring cites the
  acceptance criterion;
- switchable routes carry `require_feature(...)`; features that are not
  demo-ready ship with `default=False` (dark launch) and an admin flips them on.

## Tests that come with the endpoint

| Layer | Where | What |
|---|---|---|
| Controller | `tests/unit/api/test_<domain>.py` | 200 path, each error code as problem+json, 401 without token, 403 without scope, 404 while the flag is off — via `make_app()` with fakes |
| Service | `tests/unit/services/test_<domain>_service.py` | every branch, including `DependencyUnavailableError` translation and audit calls |
| Repository | `tests/integration/test_<domain>_repository.py` | real PostgreSQL through migrations |
| Flow | `tests/integration/test_<domain>_flow.py` | the request path end to end with `TestClient` |

Naming: `test_<unit>_<scenario>_<expected>`; `parametrize` with `ids`;
`pytest.raises(..., match=)`.
