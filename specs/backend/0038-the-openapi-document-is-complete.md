# 0038 — The OpenAPI document is complete, and a gate says so

- **Area:** backend
- **Status:** Implemented
- **Ticket:** *unassigned* · **Related:** 0019/0021 (the generated catalog artefacts, whose shape this copies), 0001 (backend foundation), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

`.claude/rules/backend/api-design.md` §2 says every operation carries a
summary, a description naming its spec, a snake_case `operation_id`, a
registered tag, a `response_model`, **every** status it can answer, request and
response examples, and a description on every schema and every field. It is the
contract a client is generated from: `client_flutter/` and `frontend/` were
both written against `/openapi.json` when this spec was written. `frontend/` is
the only one now — `client_flutter/` was retired on 2026-09-22 (spec
`repo/0002`) — which does not weaken the argument: an open-source reader
generating a client from this document is the case the spec is really about.

Nothing proved it. `tests/unit/api/test_openapi_contract.py` proved a useful
subset — a summary exists, a description is over forty characters, an operation
id is present, a 401 appears on every route not in a hand-maintained `PUBLIC`
set — and stopped there. What it could not do is the part that matters: decide
whether the statuses an operation declares are the statuses that operation can
actually produce. It had no second source to compare against, so it compared
the document with a list a person wrote.

Running the first version of the audit against `develop` found **51 findings
over 23 operations**:

| kind | count | what it was |
|---|---|---|
| `security` | 19 | The document declared **no** `securitySchemes` at all. Authentication is a plain `Authorization` header dependency rather than one of FastAPI's `security` classes, so `/docs` had no *Authorize* button and a generated client sent no token on any of the 18 authenticated routes. |
| `status-missing` | 9 | Eight routes with a request body never mentioned the 413 the body-limit middleware answers; the A2A route also omitted the 503 its database session can raise. |
| `status-unreachable` | 7 | `/health` and `/readyz` documented a 429 the rate limiter **exempts them from** by name; five routes documented FastAPI's 422 with nothing to validate; `POST /v1/view-renders` documented a 400 nothing in this service produces. |
| `schema` | 8 | `HTTPValidationError` and `ValidationError` — FastAPI's 422 envelope — sat in `components.schemas` undescribed, describing a body this service never sends. |
| `validation-shape` | 5 | Those same five 422s were `application/json` envelopes; `api.errors` answers `application/problem+json`. |
| `success-response` | 2 | The A2A 200 offered two media types and a schema for neither. |
| `request-body` | 1 | The A2A request body had an example and no schema, so no client could type it. |

A second defect was found while fixing the first and is not in that table
because the check could not yet see it: **every** error response advertised two
media types — `application/json` carrying the `ProblemDetails` schema and no
example, and `application/problem+json` carrying an example and no schema —
because `problem_responses(...)` passes `model=` and FastAPI attaches that
schema to *its* default media type. One of the two is a shape the service never
sends; the other is one a generator cannot use.

None of this is exotic. It is what a contract nobody re-derives looks like
after twenty-three routes.

## 2. Scope

**In**

- `app/api/route_facts.py` — the second source. Walks each route's dependency
  tree and reports what the route *does*: whether it authenticates, opens a
  database session, validates anything, accepts a body, and which feature flag
  guards it. `answerable_statuses()` derives the statuses this service can
  produce from the `AppError` hierarchy plus three framework ones, rather than
  listing them.
- `app/api/openapi_audit.py`, `openapi_shapes.py`, `openapi_statuses.py` — the
  rules of `api-design.md` §2 as code, each reading the operation *and* the
  facts.
- `app/api/openapi_document.py`, `openapi_errors.py` — the two corrections
  FastAPI cannot make for us: the bearer scheme, and the error media types.
  Installed by `bootstrap._configure_app`.
- `app/api/feature_gate.py` — `require_feature` now builds a `FeatureGate`
  object instead of a closure, so the flag guarding a route can be read.
- `app/api/endpoint_table.py` + `backend/docs/ENDPOINTS.md` — the human-facing
  route table, generated.
- `backend/scripts/check_openapi.py`, `make openapi-check` / `make openapi-docs`,
  the `py.openapi` gate entry, the backend-ci step and the pre-commit hook.
- The controller and schema fixes the audit found.

**Out**

- **Any behaviour change.** No route was added, removed, renamed or made to
  answer differently. Every fix here changes what the document *says* about a
  route, and the one change to a runtime object (`FeatureGate`) is an
  equivalent rewrite of a closure.
- **The `PUBLIC` set in `test_openapi_contract.py`.** It stays: a route joining
  the public set is a security decision and should need a person to write it
  down, which is a different question from whether the document is complete.
- The Flutter client's pipeline. Nothing here regenerates a client. (This line also named `client-ci`, retired with its app on 2026-09-22.)

## 3. What ships

`GET /openapi.json` now declares an `http`/`bearer` security scheme and
requires it on exactly the eighteen operations whose dependency tree contains
`get_current_principal`. Every error response is a single media type,
`application/problem+json`, carrying both the `ProblemDetails` schema and a
realistic example. Every operation documents the statuses its route can answer
and none it cannot. `components.schemas` no longer contains a shape the service
never sends.

`backend/docs/ENDPOINTS.md` is a generated table of all 23 operations — method,
path, auth, feature flag, purpose, spec — rendered from the same document, and
`backend/README.md` links to it instead of listing routes by hand.

`make openapi-check` builds the application with placeholder settings (no
`.env`, no database, nothing contacted), audits it, re-renders the table and
diffs it. It runs in `make gate`, in `backend-ci`'s Quality job and in
pre-commit, from one command string (`.claude/rules/ci-conventions.md` §5).

## 4. How it is enforced

The same shape as the catalog artefacts (0019/0021): **a generated artefact is
gated by regeneration, never by trust**, and a check that has never been shown
to reject is not a check.

- `scripts/check_openapi.py` is the only part that touches the disk or the
  process; every rule it prints is computed by covered code in `app/api/`.
- `tests/unit/api/test_openapi_audit.py` provokes **each rule** with a mutated
  operation, so the audit is known to reject and not merely to have been green.
- `tests/unit/api/test_endpoint_table.py` asserts the checked-in table matches
  the rendering, so a stale table fails the suite as well as the gate step.
- `tests/unit/api/test_openapi_document.py` asserts `/openapi.json` and `/docs`
  answer 200 and that the operation count equals what the routers carry.

## 5. Security notes

The bearer scheme is a **documentation** change: enforcement was already
`PrincipalDep` and is unchanged. The audit compares the two, so a route that
documents authentication and does not enforce it — or the reverse — is now a
finding, which is a control the `PUBLIC` list alone could not give.
`test_every_non_public_route_actually_refuses_an_unauthenticated_call` still
calls each route without a token, so "documented" and "enforced" are proven
separately and by different means.

Nothing new is exposed: `/docs` and `/openapi.json` remain off in production
(`bootstrap.create_app`), and the check contacts nothing.

## 6. Acceptance criteria

- **AC-1** — `make openapi-check` exits non-zero, naming the operation and the
  missing item, for any operation lacking a summary, description, snake_case
  operation id, registered tag, 2xx with a schema, request or response example,
  or a description on any schema or property.
- **AC-2** — It exits non-zero when an operation omits a status its route can
  answer, or declares one nothing in this service produces.
- **AC-3** — It exits non-zero when `backend/docs/ENDPOINTS.md` differs from the
  rendering, printing the diff and the command that fixes it.
- **AC-4** — `GET /openapi.json` and `/docs` answer 200, and the document covers
  every operation the routers carry.
- **AC-5** — `make gate`, `backend-ci` and `.claude/ship-gate.json` run the same
  command string, verified by `scripts/check_gate_pairs.sh`.

## 7. Test plan

| Layer | Where | What |
|---|---|---|
| unit | `test_route_facts.py` | the facts read off the real app: auth, flag, body, parameters, database; the derived answerable set |
| unit | `test_openapi_audit.py` | the real document is clean; **one mutation per rule** proves each rejection |
| unit | `test_openapi_statuses.py` | what each capability makes a route owe, and every fiction it makes a route unable to claim |
| unit | `test_openapi_shapes.py` | where an example may live, what must be described |
| unit | `test_openapi_errors.py` | the media-type fold, the dropped 422, the restored envelope |
| unit | `test_openapi_document.py` | `/openapi.json` and `/docs` answer; operation count; the scheme on exactly the enforcing routes |
| unit | `test_endpoint_table.py` | the checked-in table is the rendering |
| gate | `make openapi-check` | the whole thing, on a clean machine, on every PR |

**Test decision.** The failure this prevents is a document that disagrees with
the service — and the only way to catch that is to compare the document with
something that is not the document. So the suites assert **rules over the whole
registry of routes**, never a transcribed inventory: "every authenticated route
declares the scheme", not "these eighteen paths do". The one hard-coded number
is the operation count in `test_the_document_covers_every_operation_the_routers_carry`,
which is deliberate and carries the message *"a route was added or removed —
update the spec"*: it is the tripwire that makes adding a route touch this file.

The rejection tests are the other half. `.claude/rules/ci-conventions.md` §5
records three occasions when a check was green and wrong; the lesson applied
here is that every rule gets a test that makes it fire, built from a mutated
operation rather than from a broken controller, so the mutation is exact.

## 8. Open decisions

| # | Question | Decision | Why |
|---|---|---|---|
| OD-1 | Where does "the statuses a route can answer" come from — a list per route, or the route itself? | TL — **the route itself** | A list is a second copy of the controller, written by the same person in the same sitting, and it drifts the moment either moves. `route_facts` walks the dependency tree FastAPI itself resolves, so "this route authenticates" means the route resolves `get_current_principal`, and `answerable_statuses()` reads the `AppError` hierarchy. That is what let the check find a 429 documented on two rate-limit-exempt probes and a 400 nothing raises — neither of which a list would ever have questioned, because a person wrote both lists. |
| OD-2 | The bearer requirement: change the auth dependency to `HTTPBearer` so FastAPI emits the scheme, or post-process the document? | TL — **post-process** | `HTTPBearer(auto_error=False)` returns `None` both for a missing header and for a non-`Bearer` scheme, which would collapse `auth/missing-token` and `auth/invalid-token` into one and change what a caller is told. That is a behaviour change to fix a documentation bug. The document builder applies the scheme to exactly the routes whose tree contains `get_current_principal`, so the declaration is derived from enforcement rather than kept in step with it. |
| OD-3 | `require_feature` returned a closure, which hides its key. Expose the key, or keep a list of which flag guards which route? | TL — **expose the key** | The closure was unreadable on purpose about nothing — it was simply the shortest way to write it. `FeatureGate` is the same dependency as an object with `key` and `default` on it, so the audit can require a 404 where a gate really is, and `ENDPOINTS.md` can print the flag. A list would be the OD-1 mistake again, one file over. |
| OD-4 | The route list in `backend/README.md` was seven operations short. Fix it, or generate it? | TL — **generate it** | It had been fixed before. A hand-written list of routes is a copy of the router, and 0019 already settled what this repository does with copies: it renders them and diffs them. `ENDPOINTS.md` costs one `make openapi-docs` and cannot be wrong for longer than one gate run. |
| OD-5 | The A2A request body and its event stream have no model FastAPI can derive. Inline the schema, or leave the body schemaless? | TL — **inline it** | A body with an example and no schema is a body a generated client cannot type, which is the thing this spec exists to remove. `JsonRpcRequest` already exists and has no nested models, so `model_json_schema()` is exact and self-contained; `JsonRpcFailure` reaches `components` through `model=` on the 200. The event stream is `text/event-stream` and genuinely has no JSON schema, so it is declared as the string it is, with the framing described. |
| OD-6 | FastAPI's own 422 is attached to any operation with a parameter — including the optional `Authorization` header, which cannot fail. Exclude header parameters from "validates input", or accept the 422? | TL — **exclude them, and delete the response** | Accepting it would document a 422 on `GET /v1/me`, which takes nothing that can be malformed. `validates_input` therefore counts a body, a path parameter or a query parameter and not a header, and the document builder deletes a 422 no controller declared. The two halves check each other: if a route really can fail validation and its controller says nothing, the audit reports the *missing* 422 rather than silently accepting the deleted one. |
| OD-7 | Should the check assert the whole document byte-for-byte, the way `catalog-check` does for its artefacts? | TL — **no; audit the rules, diff only the table** | A byte-for-byte snapshot of `/openapi.json` would turn every FastAPI upgrade and every field description into a diff nobody reads, and it would prove the document is *unchanged*, not that it is *complete* — the distinction 0021 §4 draws. The rules are what `api-design.md` actually requires. `ENDPOINTS.md` is diffed because it is a rendering we own end to end. |
