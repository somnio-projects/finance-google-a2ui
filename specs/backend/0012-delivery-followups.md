# 0012 — Delivery follow-ups: incremental surfaces, the batch render, revalidation

- **Area:** backend
- **Status:** Implemented
- **Ticket:** — (no Jira ticket; these are follow-ups already decided in the ADRs and recorded as open decisions in specs 0005 and 0010) · **Related specs / ADRs:** [0005](0005-presentation-layer.md), [0006](0006-agent-host.md), [0010](0010-a2a-surface.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-18/D-19/D-20, [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

ADR-K's *Delivery speed* section is the part of the response-shaping decision
that is not built. Three of its rulings shipped as written-down intentions
instead of code, and each one is visible in the tree as a caveat:

- **D-19** wants a surface emitted the moment it exists. `AgentService.run_turn`
  returns a finished turn, so `services/a2a_service.py` can only emit a
  `working` status and then everything at once — its own module docstring says
  so, and spec 0010 OD-3 carries it as an open decision.
- **D-18** wants `POST /v1/view-renders`, the heterogeneous batch with a
  per-entry status. Nothing serves it, so a client wanting two views over two
  resources pays two round trips and loses all of them if one fails.
- **D-20** wants a strong `ETag`, a `Cache-Control` and a 304. The view reads
  answer 200 with a full body every time, although `as_of` is fixed at seed
  time (ADR-F D-6) and the body is byte-identical for the life of a session.

The demo is judged on how fast the first widget appears (ADR-K's latency
budget: < 1 s to the first streamed surface). All three gaps push in the wrong
direction.

A fourth follow-up — resolving an A2A `contextId` against the authenticated
subject and loading that conversation's history — is **out**; see OD-3.

## 2. Scope

**In:**

- `AgentService.run_turn_events`, an async generator yielding `SurfaceReady`
  per render intent and one terminal `TurnCompleted`; `run_turn` kept as a thin
  collector so every existing caller is unchanged.
- The model/tool loop extracted to `services/agent_loop.py` so it can yield.
- `services/a2a_service.py` forwarding a `render-intent` event per surface,
  with the event shapes split into `services/a2a_events.py`.
- `POST /v1/view-renders` — the batch render resource, per-entry status,
  exhaustively documented, capped at `MAX_RENDERS`.
- `api/caching.py` — a reusable strong-`ETag` / `If-None-Match` / 304
  dependency, applied to both view reads.
- `presentation/endpoints.py`, so a serving endpoint is named once instead of
  in every view module.
- **Enforcing the OpenAPI *examples* rule**, which was documented and unchecked
  — see §6 AC-10 and OD-6.

**Out:**

- **`contextId` resolution and conversation history** — the session code
  (GGU-46) is not on this branch. See OD-3.
- In-process memoisation of the domain build and of each render (the other
  half of ADR-K D-20). See OD-4.
- Compression at the edge and the `fields` option (ADR-K D-21) — already
  owned by spec 0005.
- `tasks/cancel`, push notifications (ADR-D D-9, spec 0010 OD-4).

## 3. API contract

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `POST /v1/view-renders` | Bearer | `ViewRenderBatch` | **201** `ViewRenderBatchResults` | `malformed-request → 400/422` · `auth/* → 401` · `feature-disabled → 404` · `rate-limited → 429` · `dependency-unavailable → 503` |
| `GET /v1/portfolios/{portfolio_id}/views` | Bearer | `If-None-Match` (optional) | 200 + `ETag` + `Cache-Control`, or **304** | unchanged from 0005 |
| `GET /v1/views` | Bearer | `If-None-Match` (optional) | 200 + `ETag` + `Cache-Control`, or **304** | unchanged from 0005 |

**`ViewRenderBatch`** — `renders`: 1…`MAX_RENDERS` (8) entries, `extra="forbid"`.
Each `ViewRenderRequest` is `{view: ViewId, portfolio_id: str = "current",
options: dict}` with `options` capped at `MAX_OPTIONS` (16) keys; the
projection's own options model then rejects anything it does not declare
(ADR-K D-3).

**`ViewRenderBatchResults`** — `results`: one `ViewRenderResult` per entry, in
request order, each `{status, view, portfolio_id, as_of?, payload?, error?}`.
`payload` is the discriminated union over every registered projection;
`error` is an RFC 9457 `ProblemDetails` **without** `instance` or `request_id`,
which belong to the batch request and travel in its `X-Request-ID` header.

The batch answers **201** whenever it was well formed, per ADR-K D-18, and
carries **no `Location`** — see OD-1.

**A2A stream**, per turn: `status-update{working}` → `render-intent`\* →
`message` → `status-update{completed | input_required}`. `render-intent` is
`{kind, taskId, contextId, index, renderIntent}`. It is **additive**: the
terminal `message` still carries the full `renderIntents` list, so a client
written against spec 0010 AC-2 is unaffected.

## 4. Data model & migration

None. No table, column or Alembic revision — every change is in-memory or on
the wire.

## 5. Security notes

- `POST /v1/view-renders` is authenticated through the same `PrincipalDep` as
  every other `/v1` route and gated by `views.batch-render`. **A batch entry
  cannot name another subject's portfolio**: `ViewService.portfolio` accepts
  only the well-known `current` and 404s everything else, so the batch inherits
  spec 0005 §5 unchanged. Asserted by a test.
- A per-entry `error` is built from `AppError.code`/`detail`, both already safe
  for an anonymous caller. No exception text, no option value and no subject
  reaches an entry's problem document.
- The portfolio read's `ETag` is a SHA-256 digest that **includes the
  subject**, so two callers can never share an entity tag for that URL. The
  digest is one-way: the tag discloses nothing about the portfolio it
  describes. (The catalog's tag does not include the subject, and must not —
  the catalog is byte-identical for every caller.) Both responses carry
  `Cache-Control: private, no-cache` and `Vary: Authorization`: a client may
  keep a body but must revalidate before reusing it, so a feature flag that
  switches a route off takes effect at once, and no intermediary may key a
  subject-scoped body on the URL alone.
- `If-None-Match` is bounded (`max_length=512`) like every other input; the
  batch body is bounded by `BodyLimitMiddleware` and by the DTO's own caps.
- No new public route; `tests/unit/api/test_openapi_contract.py::PUBLIC` is
  unchanged, and the unauthenticated sweep now also covers the new route.
- No new audit event: rendering a projection is a read of the caller's own
  data, like the reads spec 0005 already covers.

## 6. Acceptance criteria

1. **AC-1** — `AgentService.run_turn_events` yields one `SurfaceReady` per
   render intent, indexed from zero, in production order, **before** the
   `TurnCompleted` that carries the answer.
2. **AC-2** — The A2A stream emits a `render-intent` event per surface, ahead
   of the terminal `message`, and the `message` still carries every intent.
3. **AC-3** — `run_turn` returns the same `TurnResult` as before, and the turn
   records exactly one metric and one log line on **every** path: `ok`,
   `model-unavailable`, and `error` for anything untranslated. Every failure
   reaches `ErrorReporter.capture_exception` before it is re-raised, because
   the A2A transport above can only turn it into a terminal event.
4. **AC-4** — `POST /v1/view-renders` renders up to `MAX_RENDERS` entries in
   one authenticated round trip and answers 201 with one result per entry, in
   request order.
5. **AC-5** — An entry that fails (unknown view → 404, undeclared or
   out-of-range option → 422, another portfolio → 404) carries its own status
   and problem document, and **every other entry still renders**.
6. **AC-6** — An empty batch, one over the cap, an undeclared field, a
   malformed view or portfolio id, or an over-sized options object is a 422
   RFC 9457 problem document for the whole request.
7. **AC-7** — Both view reads answer a strong quoted `ETag` and a
   `Cache-Control`; a request repeating that tag in `If-None-Match` answers
   **304 with an empty body**; a different view or option yields a different
   tag and a 200.
8. **AC-8** — The `ETag`/304 behaviour arrives as a reusable dependency in
   `api/caching.py` with its own tests, covering an absent header, `*`, a
   list, a weak tag and a miss — not as code inside a controller.
9. **AC-9** — Every new operation and DTO field is documented per
   `.claude/rules/backend/api-design.md`: summary, description, `operation_id`,
   tags, `response_model`, every error response from `problem_responses`,
   request and response examples, and bounds on every field.
10. **AC-10** — Every non-generated operation documents at least one
    **response** example, and every operation accepting a body documents at
    least one **request** example, asserted by a test that names the offending
    route. An operation that genuinely cannot carry one is listed, with its
    reason, in an explicit constant. Existing routes are fixed by adding real
    examples, never by weakening the assertion.
11. **AC-11** — `make gate` green: 150-line budget, basedpyright strict,
    quality gates, **100 % branch coverage**, pip-audit.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/services/test_agent_streaming.py::test_a_surface_is_emitted_before_the_turn_completes`, `…::test_every_surface_is_emitted_once_and_in_order`; `tests/unit/agent/test_turn_state.py` | — |
| AC-2 | `tests/unit/services/test_a2a_streaming.py::test_a_surface_is_streamed_before_the_answer`, `…::test_the_terminal_message_still_carries_every_intent` | — |
| AC-3 | `tests/unit/services/test_agent_streaming.py::test_run_turn_still_returns_the_finished_result`, `…::test_a_dead_model_is_reported_once_and_re_raised`; `tests/unit/services/test_agent_failures.py::test_run_turn_reports_and_counts_an_untyped_failure`; `test_a2a_service.py::test_an_unexpected_failure_still_ends_the_stream` (asserts the stream swallows it *and* the turn reported it) | — |
| AC-4 | `tests/unit/api/test_view_renders_endpoint.py::test_a_batch_renders_every_entry_in_one_round_trip` | `tests/integration/test_views_flow.py::test_a_batch_renders_across_entries_with_per_entry_status` |
| AC-5 | `tests/unit/services/test_view_render_service.py` (all five); `tests/unit/api/test_view_renders_endpoint.py::test_one_failing_entry_does_not_sink_the_others` | same as AC-4 |
| AC-6 | `tests/unit/api/test_view_renders_endpoint.py::test_a_malformed_batch_is_a_422_problem_document` (7 ids) | — |
| AC-7 | `tests/unit/api/test_view_caching.py` (6 tests) | `tests/integration/test_views_flow.py::test_a_repeated_view_read_revalidates_to_304` |
| AC-8 | `tests/unit/api/test_caching.py` (15 cases) | — |
| AC-9 | the existing `test_openapi_contract.py` and `test_openapi_projections.py` sweeps, plus `test_view_renders_endpoint.py::test_the_operation_documents_the_union_and_both_examples` and `test_view_caching.py::test_both_reads_document_their_304` | — |
| AC-10 | `tests/unit/api/test_openapi_examples.py` (3 tests: response examples, request examples, and that the exemption list names only live routes) | — |
| AC-11 | `make gate` | included |

Mutation checks required (auth / rate limit / error masking): **no new auth or
masking logic** — the batch route reuses `PrincipalDep`, `require_feature` and
the existing problem handler, and the per-entry problem is built from
`AppError` fields the handler already emits. The unauthenticated sweep in
`test_openapi_contract.py` covers the new route by construction, so a missing
`PrincipalDep` would turn it red.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | ADR-K D-18 says the batch answers **201**, but `.claude/rules/backend/api-design.md` pairs 201 with a `Location`. Which wins? | TL — **201 without `Location`** | The ADR is the more specific decision and RFC 9110 §15.3.2 makes `Location` optional. Nothing durable is created: the batch is computed and returned, and is not retrievable afterwards, so any address would be a lie. Stated in the operation's description and asserted by a test. Revisit only if batches become persisted jobs. |
| OD-2 | The A2A protocol has no event for "a surface is ready". Invent one, or reuse `artifact-update`? | TL — **a `render-intent` event, additive** | A2A is alpha and its artifact semantics are unsettled; mapping a render intent onto `artifact-update` would guess at a contract we do not control. The new kind lives in one module (`a2a_events.py`), and the terminal `message` still carries the full list, so no client breaks and the mapping can change with one file when A2A settles. |
| OD-3 | Resolving `contextId` against the authenticated subject and loading history (ADR-J D-4, ADR-A; spec 0010 OD-2). | TL — **deferred, not attempted here** | **The session code is not on this branch.** GGU-46 merged onto `ggu46-integration`, which `feat/GGU-3_a2a_surface` was not rebased onto: there is no `SessionService`, no `conversation_session` model and no `session_repository` in this tree, so there is nothing to resolve a `contextId` against. Implementing it would have meant inventing a session store this stack already has elsewhere. `a2a_service.py` still passes `history=[]` and says so in its docstring. **Whoever rebases this stack onto the session work owns this**, and the rule is unchanged: resolve against the verified subject or treat as unknown — never trust the id on its own. |
| OD-4 | The other half of ADR-K D-20: memoising the domain build per session and each render per options hash. | TL — **not in this change** | A 304 already removes the body from the wire, which is the expensive part. A render cache keyed by *(subject, view, options)* is unbounded memory in a process that seeds a portfolio per subject, so it needs an eviction decision rather than a decorator. The latency budget is met without it today (two projections over an in-memory portfolio); revisit when a projection is measured over the budget. |
| OD-6 | `.claude/rules/backend/api-design.md` §2 has always required a request and a response example on every operation, and **nothing enforced it**: `test_openapi_contract.py` checks summaries, ids, tags, statuses, parameters and schema properties, and `test_openapi_projections.py` checks only the projection half. Enforce it now, or leave it to the route that needs it? | TL — **enforce it now, in this PR** | An unenforced rule is a rule that quietly stops being true, which this project has already been bitten by twice. The new sweep turned eight existing operations red — the two health probes, both feature-flag routes, the two identity reads, the view catalog and the agent card. Every one was fixed by adding a real example with realistic values, none by relaxing the test. The catalog's example is **generated from the registry** through the new `contract.catalog_entry`, which the route's DTOs are also built from, so the documented catalog cannot drift from the served one. `POST /` (A2A) is the single exemption, named with its reason: it is one JSON-RPC envelope for many methods and answers either an event stream or an error object, so it has no single schema to exemplify. |
| OD-5 | Should `POST /v1/view-renders` accept entries for resources other than portfolios? | TL — **portfolios only, for now** | ADR-K D-18 says `{resource, view, options}`; every projection registered today is a portfolio projection, so the entry names `portfolio_id`. Generalising to an opaque resource reference before a second resource exists would be a shape with no user. Adding one later is a new optional field, not a breaking change. |

## 9. Rollout & observability

- One new feature flag key, `views.batch-render`, defaulting to **on** like the
  other view gates (`api/feature_gate.py`); the `FEATURE_FLAGS_FORCE_DISABLED`
  kill-switch covers it for free.
- No new metric. The turn's single `agent.turn` metric is unchanged — the
  incremental events are emitted inside the same turn and add no counter, and
  deliberately no per-surface log line: that would put the conversation's shape
  into the logs, which spec 0006 §5 forbids.
- Sentry expectations: a non-`AppError` inside a batch entry is a defect and
  still reaches the catch-all handler and the reporter, rather than being
  flattened into an entry's problem document. Inside a **turn**, the same class
  of failure is reported by `run_turn_events` with `outcome="error"` before it
  is re-raised — the A2A stream can only emit a terminal event by then, so the
  turn is the last place that can still report it.
- No migration, so no ordering concern.
