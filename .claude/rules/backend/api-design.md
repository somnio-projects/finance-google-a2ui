# Backend API design rules — REST + OpenAPI

Every HTTP surface in `backend/` follows these. They are checked by the
`backend-reviewer` agent and by review; a route that breaks one is not done.

## 1. RESTful by construction

| Rule | Concretely |
|---|---|
| Resources, not actions | `/v1/feature-flags/{key}`, `/v1/portfolios/{id}/holdings` — plural nouns, kebab-case, no verbs in the path (`/getHoldings` is wrong) |
| The verb carries the semantics | `GET` safe and cacheable · `POST` creates (201 + `Location`) or runs a computation on a sub-resource · `PUT` full, idempotent replace/upsert · `PATCH` partial update · `DELETE` removes (204) |
| Status codes are part of the contract | 200 / 201 / 202 / 204 · 400 malformed · 401 unauthenticated · 403 unauthorised · 404 missing **or feature-disabled** · 409 conflict · 412/428 precondition · 422 semantic validation · 429 rate limited · 503 dependency down |
| Collections | `GET /v1/<resources>` returns a list DTO; filtering/sorting/pagination through **query parameters** (`?limit=&cursor=&sort=`), never in the path; every parameter is bounded (`ge`, `le`, `max_length`) |
| Sub-resources for relations | `/v1/me/audit-events`, not `/v1/audit?who=me` |
| Idempotency | `PUT` and `DELETE` are idempotent; a `POST` that must be retried safely takes an `Idempotency-Key` header and documents it |
| Errors | always RFC 9457 `application/problem+json` through `AppError` → `problem_response`; never a bare string or a custom error shape |
| Versioning | `/v1` prefix on every business route; breaking a contract means `/v2`, not mutating `/v1` |
| No RPC escape hatches | a computation is a resource (`POST /v1/portfolios/{id}/attribution-runs`) or a sub-resource read (`GET /v1/portfolios/{id}/attribution?window=7d`) |

Health and infrastructure routes (`/health`, `/readyz`) are the only
non-versioned, non-resource routes and are documented as such.

## 2. OpenAPI: everything is documented

On **every** operation:

- `summary=` (imperative, ≤ 60 chars) and `description=` (what it does, auth required, side effects, the spec/AC it implements).
- `operation_id=` in `snake_case`, stable — it is the client's generated method name.
- `tags=[...]` from the tag list registered in `bootstrap.create_app` (each tag has a `description`).
- `response_model=` with `response_model_exclude_none` when the DTO has optionals, and an explicit `status_code=` when it is not 200.
- `responses={...}`: **every** status the route can answer, each with `model=ProblemDetails` (use `app.api.openapi.problem_responses(...)`) and a one-line description. A 401 on an authenticated route, a 403 where a scope is required, a 404 where a flag gates it, 429 and 503 where they apply — all listed.
- At least one request example and one response example (`openapi_examples` or `json_schema_extra`), using realistic finance values.

On **every** DTO field: `Field(..., description=..., examples=[...])` plus the bound (`max_length`, `ge`, `pattern`). On every schema class: a docstring — it becomes the schema description.

The generated document is part of the deliverable: `GET /openapi.json` must be complete enough that a client generator produces usable code with no hand-editing.

## 3. Patterns and DRY

- Layering and the 150-line budget from `.claude/rules/backend/architecture.md` — controller resolves `Depends`, calls one service method, returns the DTO.
- Repeated response blocks, dependencies, pagination parameters or error sets live in **one** place (`app/api/openapi.py`, `app/api/deps.py`, a base schema, `BaseRepository[ModelT]`, a Protocol) and are reused. Copy-pasting an OpenAPI `responses` dict into two controllers is a review blocker.
- A third occurrence of anything is a refactor, not a third copy.
- New cross-cutting behaviour (pagination, idempotency, ETag) arrives as a reusable dependency or helper with its own tests, not inline in a controller.

## 4. Checklist before the PR

- [ ] Path is a resource; verb and status codes match the semantics above.
- [ ] `summary`, `description`, `operation_id`, `tags`, `response_model`, full `responses`, examples.
- [ ] Every field documented and bounded; docstring on every schema.
- [ ] Auth dependency present (or the spec justifies a public route); scope checked in the service.
- [ ] Shared pieces reused, nothing duplicated; file ≤ 150 lines.
- [ ] `/docs` renders the route correctly and the tests assert the documented statuses.
