# ADR-K — Response shaping: server-side projections, not client-side transformation

- **Status:** **Accepted** — ratified by the TL (Lautaro Bertuzzi) on 2026-09-19
- **Gates:** every read endpoint that feeds a UI component; GGU-16–21 (catalog), GGU-36–39 (tools), GGU-41 (frozen schemas), GGU-49
- **Evidence anchor:** `develop` @ PR #2 + PR #9
- **Related:** [ADR-J](ADR-J-rest-api-and-a2a-surface.md) (surfaces), [ADR-E](ADR-E-money-representation.md) (money), `.claude/rules/backend/api-design.md`

## Context

> **In the context of** six catalog components — attribution waterfall, tax-lot table, scenario
> card, order ticket, risk/payoff chart, holdings summary — each needing a **different payload
> shape**, **facing** a hard product rule that the client performs **zero transformation** (it binds
> what it receives) and a hard API rule that everything stays RESTful and exhaustively documented,
> **we decided** to put a **presentation layer** in the backend that renders named, versioned
> **projections** driven by declared options, **and neglected** GraphQL and a free-form query DSL,
> **to achieve** a payload per widget that is exactly what the widget binds to — typed, documented,
> cacheable and testable — **accepting that** adding a widget variant means adding a projection
> server-side rather than reshaping on the client.

The alternative everyone reaches for first is "return the raw model and let the client map it".
That is exactly what the showcase argues against: the model must not compute or format numbers on
the client ([ADR-E](ADR-E-money-representation.md)), and an LLM-composed surface cannot be asked to
invent a mapping at render time.

## Decision

- **D-1 — A projection is a first-class, named, versioned thing.** Identifier `"<component>.<variant>.v<N>"` (e.g. `attribution.waterfall.v1`, `holdings.allocation.v1`, `taxlots.table.v1`). A client asks for it by name; the server owns the shape.
- **D-2 — The client selects a projection with the `view` query parameter**, documented and bounded per endpoint (`GET /v1/portfolios/current/attribution?view=attribution.waterfall.v1&window=30d`). Each endpoint declares a default `view`, so a caller that does not care gets a sensible payload.
- **D-3 — Elasticity comes from declared options, never from a free-form DSL.** Each projection publishes a pydantic **options model** — bounded, defaulted, documented field by field (`top_n`, `include_other`, `sort`, `locale`, `currency`, `precision`, `fields`). Shared knobs live in reusable option mixins. Anything not declared is rejected with 422; nothing is interpreted at runtime.
- **D-4 — The response is a discriminated union.** Every projection DTO carries a literal `view` field; the endpoint's `response_model` is the union, documented in OpenAPI as `oneOf` with a `discriminator` and **one example per projection**. A generated client gets real types, not `Any`.
- **D-5 — Every number in a projection is a pre-formatted `*Display` string** produced server-side under the money rules; raw `Decimal` values may accompany them for charting, never instead of them. The client never rounds, never formats, never computes a percentage.
- **D-6 — Projections are pure.** A projection maps *domain result + options → DTO*. It performs no I/O, holds no business rule, and never reaches into a repository; it lives in `app/presentation/` and is unit-tested in isolation. A rule that belongs to the domain does not migrate into a presenter because it was convenient.
- **D-7 — Registration is local.** A projection registers itself from its own module through the registry; adding one never edits a shared file. This is the same seam the deterministic tools use.
- **D-8 — The catalog is introspectable.** `GET /v1/views` lists every registered projection with its id, the endpoints that serve it, its options schema and an example payload. This is the RESTful, documented answer to "how does the client discover what it can ask for" — GraphQL's introspection without GraphQL.
- **D-9 — Versioning is additive.** A new variant is a new id; an existing id's shape is frozen once a client binds to it. Removing one needs a deprecation note in `CHANGELOG.md` and a release cycle. `v1` ids map 1:1 to the schemas GGU-41 freezes as the design contract.
- **D-10 — The default is the widget's shape, not the model's.** When in doubt, ship the projection the component needs, not the entity as the database stores it.
- **D-11 — Two drivers, one registry.** A projection is selected either by the **client** (`view` query parameter, D-2) or by the **agent** — the model emits a *render intent* `{view, options}` as part of its tool call, and the backend renders it. Both paths resolve through the **same registry**, the same options models and the same validation.
- **D-12 — The model chooses, it does not invent.** A render intent is validated against the registry before anything is rendered: an unknown `view`, an undeclared option or an out-of-range value is **rejected**, and the turn falls back to the endpoint's default projection with the rejection recorded in telemetry. The model never defines a payload shape, never adds a field and never supplies a formatted number — it picks a registered view and fills declared options ([ADR-E](ADR-E-money-representation.md), numbers-from-tools).
- **D-13 — The backend may decide on its own.** When the model expresses no preference, a deterministic **selection rule** per endpoint picks the projection from the data (for example: a single holding → detail card; many → allocation summary; a window with a residual bucket → waterfall). The rule is code, it is tested, and it is documented next to the projection so the demo is reproducible.
- **D-14 — The registry is the single source of truth for five consumers.** Registering a projection once publishes it to: the **OpenAPI** document (union member + example), the **`/v1/views` catalog** (D-8), the **prompt fragments** that teach the model the catalog (GGU-14) — generated from the registry, never hand-copied — the **A2UI surface** emission for the genui client, and the **frozen component contract** `docs/catalog/CONTRACT.md` (GGU-41), regenerated and diffed by the gate so a projection cannot change without the design contract changing with it. Because `genui`/`a2ui_core` are alpha and their catalog will move, this indirection is what keeps a library bump from touching business code: the mapping to A2UI lives in one adapter per projection.

- **D-15 — Adding a chart is an additive change, by construction.** The six catalog components are today's set, not the final one: the client will ask for more. A new chart must therefore **edit no existing file** — the projection, its options model, its DTO, its A2UI adapter and its tests arrive as new modules, registered from the view's own module and nothing else. (It may *create* more than one: a chart whose options are a domain object does not fit its DTO, options and builders into the 150-line budget. Four of the six do not. The budget is a gate; "one module" was a preference, and the guarantee that matters is the *no edit* half.) No shared file is edited, no existing payload changes, no client is broken, and the new view appears automatically in OpenAPI, in `/v1/views` and in the prompt fragments (D-14). **A design that requires touching a shared registry list, a central enum or an `if/elif` chain to add a chart is a failed implementation of this ADR** and must be refactored rather than extended.
- **D-16 — Composition over new primitives.** Prefer building a new chart out of the existing primitives (series, buckets, categories, totals, annotations, `*Display` pairs) declared as reusable DTO fragments, so the tenth chart reuses what the first nine established instead of inventing a tenth vocabulary. A genuinely new primitive is allowed — it is added to the shared fragment set with its own tests and documented in the same PR.

## Delivery speed

A dashboard paints several widgets at once; the demo is judged on how fast the
first pixel appears. Batching is the usual reason teams reach for GraphQL, so
the design answers it directly.

- **D-17 — One request can carry several projections.** A read endpoint accepts a repeated `view` parameter (`?view=holdings.allocation.v1&view=attribution.waterfall.v1`, capped at a documented maximum) and answers a **keyed object**, one entry per view. One authentication, one session, one database round trip, one domain build — then *N* pure in-memory renders. This is the batching benefit without a second query language.
- **D-18 — Heterogeneous batches are a resource.** When views span different resources, the client creates a batch: `POST /v1/view-renders` with a list of `{resource, view, options}` → **201** with the rendered results and a per-entry status, so one failing view never fails the others. It stays REST because the batch *is* a resource, and it stays documented like any other endpoint.
- **D-19 — Inside an agent turn, surfaces stream as they are ready.** The A2A path emits each surface incrementally rather than waiting for the full answer ([ADR-D](ADR-D-a2ui-streaming-transport.md)), so perceived latency is the time to the *first* widget, not to the last.
- **D-20 — Projections are cacheable because they are pure.** A response carries a strong `ETag` derived from *(resource version, view id, options, `as_of`)* and an explicit `Cache-Control`; a revalidation answers **304**. In-process: the domain build is memoised per session and each render memoised per *(view, options)* hash. Because `as_of` is fixed at seed time (ADR-F), a given request is byte-identical for the life of the session — the cheapest possible cache key.
- **D-21 — The payload is small by construction.** The `fields` option trims what the widget does not bind; raw `Decimal` values accompany `*Display` strings only when the option asks for them; responses are compressed at the edge. A projection that ships data no widget reads is a bug, not a convenience.

**Latency budget** (documented, measured in the integration suite and alerted in production): **p95 < 150 ms** server time for a warm projection read, **< 400 ms** cold, and **< 1 s** to the first streamed surface in an agent turn. A projection that cannot meet it moves its heavy work into the domain layer where it can be precomputed at seed time — never into the client.

**On GraphQL, again.** Its real draw here would be batching, and D-17/D-18 deliver that at a fraction of the cost. If a future client genuinely needs arbitrary traversal, it can be added **later** as a separate read-only surface alongside the A2A adapter (ADR-J allows exactly that shape of addition) — an additive decision, not a rewrite. We are not closing that door; we are declining to open it for a need we do not have.

## Consequences

**Positive.** The client binds and renders — no mapping layer, no drift between what Figma froze and what the API returns. Each projection is a small pure function with its own tests, so a widget change is a contained diff. The payloads stay documented and typed, so the OpenAPI contract test keeps covering them. Caching stays possible because the URL fully describes the response.

**Negative / accepted.** More server-side code than "return the entity": one presenter and one options model per widget variant. A new chart needs a backend change, so backend and design must move together (GGU-41 is what makes that cheap). The union response is slightly heavier to document — mitigated by the shared `problem_responses`/registry helpers.

**Known limit — the Protocol is bound to `Portfolio`, and D-6 is worded more loosely than the code.** D-6 says *"domain result + options → DTO"*. The code says `Portfolio`, in three places at once: `Projection.render` is `Callable[[Portfolio, Any], ProjectionDto]`, `Projection.fitness` is `Callable[[Portfolio], int]`, and `ProjectionSpec.example` renders against `sample_portfolio()`. Because `Callable` is contravariant in its arguments, a `render(SomeOtherResult, …)` is **not** assignable and basedpyright rejects it at `register(...)` — so `spec.py`'s suggestion to "implement the Protocol itself" is not an escape: the Protocol is the monomorphic thing.

The four charts added by GGU-41 fit **only because their domain results are derivable from a `Portfolio` by a pure function** — `simulate_sale` and `payoff_curve` read no clock and no repository, and `as_of` rides on the portfolio. Four agents implementing them independently reached this same conclusion and recorded it separately (specs 0015 OD-1, 0016 OD-1, 0017 OD-1); it is written here so the fifth does not have to rediscover it.

**What will not fit:** a projection over a domain result that cannot be derived that way — one needing a repository read, a second aggregate, or a clock. Closing it means parameterising `Projection`/`ProjectionSpec` over the domain result and giving `example` a per-projection sample. That is a real change to this ADR and is deliberately **not** made here: no such projection exists yet, and widening the seam speculatively would cost every current view a type parameter it does not use. **Whoever needs it should amend this ADR rather than work around the signature.**

**Neglected alternatives.**
- *GraphQL*: genuinely dynamic, but it abandons the REST rule that governs `/v1` ([ADR-J](ADR-J-rest-api-and-a2a-surface.md)), splits the surface in two, makes exhaustive OpenAPI documentation impossible, needs its own auth/depth/complexity limiting, and buys flexibility the client does not need — it needs *six known shapes*, not arbitrary ones.
- *A free-form projection DSL in the query string* (jbuilder-style templates sent by the client): unbounded input shaping the response is an injection and denial-of-service surface, cannot be documented exhaustively, and cannot be held at 100 % branch coverage. D-3 keeps the elasticity and drops the open interpreter.
- *Client-side transformation*: contradicts the product invariant and duplicates finance arithmetic in Dart.

## Compliance

`.claude/rules/backend/presentation.md` carries the enforceable rules. The OpenAPI contract test
(`backend/tests/unit/api/test_openapi_contract.py`) is extended so that a projection without a
documented example, an options schema or a discriminator literal fails the gate.
