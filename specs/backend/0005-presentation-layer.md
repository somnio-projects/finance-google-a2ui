# 0005 — Presentation layer: versioned projections, declared options and the `/v1/views` catalog

- **Area:** backend
- **Status:** Implemented
- **Ticket:** GGU-49 · **Related specs / ADRs:** 0003 (portfolio domain), ADR-K (the specification of this ticket), ADR-J, ADR-E, ADR-F · rule `.claude/rules/backend/presentation.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The six catalog components each need a **different payload shape**, and the
product rule is that the Flutter client performs **zero transformation**: it
binds what it receives. Today the backend has a portfolio (spec 0003) and no
way to shape it. Epic 1's tools, GGU-14's prompt fragments, GGU-41's frozen
schemas and GGU-47's agent turn all need the same seam:

- a **named, versioned projection** the client (or the model) asks for by id;
- **declared, bounded options** instead of a free-form query DSL;
- a **registry** that publishes each projection to OpenAPI, to a catalog
  endpoint, to the generated prompt fragments and to the A2UI adapter.

[ADR-K](../../docs/adr/ADR-K-response-shaping.md) decides all of this; every
`D-n` ruling in it is a requirement of this spec. The single hardest
constraint is **D-15**: adding a chart must cost *one new module*. A design
that needs a shared list, a central enum or an `if/elif` chain edited to add a
view is a failed implementation and must be refactored rather than extended.

## 2. Scope

**In:**

- A new framework-free package `backend/src/app/presentation/`:
  `registry.py` (the `Projection` Protocol, the `ProjectionSpec` dataclass, the
  registry and local `register(...)`), `fragments.py` (reusable DTO
  primitives), `options.py` (reusable bounded option mixins), `formatting.py`
  (the single `Decimal` → `*Display` boundary), `selection.py` (the
  no-preference rule), `prompt.py` (generated prompt fragments), `contract.py`
  (the registry-derived discriminated union, response model and OpenAPI
  examples), `sample.py` (the fixed-instant portfolio examples are rendered
  from) and `views/` with the two reference projections.
- Two reference projections: `holdings.allocation.v1` and
  `attribution.waterfall.v1`, each one module holding its id, options model,
  DTO, pure `render`, A2UI adapter and `register(...)` call.
- `GET /v1/portfolios/{portfolio_id}/views` — repeated `?view=`, capped,
  documented, default documented; answers a **keyed object**, one entry per
  requested view, as a discriminated union.
- `GET /v1/views` — the catalog: id, serving endpoints, options JSON schema,
  example payload.
- `RenderIntentService` — the service-level entry point the agent turn calls
  with `{view, options}`; validates against the same registry, reports rejections
  through the injected `ErrorReporter` and falls back to the endpoint default.
- The OpenAPI contract test extended so a projection without an example, an
  options schema or its discriminator literal fails the gate.

**Out:**

- `POST /v1/view-renders`, the heterogeneous batch (ADR-K D-18) — a later
  ticket; D-17's repeated `?view=` covers the demo's dashboard.
- `ETag` / `Cache-Control` / memoisation (ADR-K D-20) — a later ticket; the
  projections are pure, so caching is additive and changes no payload.
- The remaining four catalog components (tax-lot table, scenario card, order
  ticket, risk/payoff chart) — Epic 1 adds one module each, by construction.
- The agent turn itself, the prompt assembly and the A2UI emission over the
  wire — GGU-47 and GGU-14 consume what this spec registers.
- Session persistence of the portfolio — GGU-46 behind the same
  `PortfolioProvider` Protocol.

## 3. API contract

Both routes belong to the **REST surface** (ADR-J D-1) and carry the new
`views` tag registered in `app/api/openapi.py`.

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `GET /v1/views` | Bearer | — | `list[ViewDescriptor]` | `auth/* → 401`, `rate-limited → 429`, `feature-disabled → 404`, `internal → 500` |
| `GET /v1/portfolios/{portfolio_id}/views` | Bearer | repeated `?view=` + declared options | `PortfolioViewsResponse` | `malformed-request → 422`, `validation-failed → 422`, `portfolio/unknown-view → 404`, `auth/* → 401`, `rate-limited → 429`, `feature-disabled → 404`, `internal → 500` |

`portfolio_id` is `current` today — the well-known id of the authenticated
caller's portfolio, exactly as `/v1/me` names the caller. Any other id answers
**404 `not-found`**: a subject may only read its own portfolio (ADR-F).

**Query parameters** (one pydantic model, `extra="forbid"`, so an
**undeclared** query parameter is a 422 before any projection runs):

| Parameter | Type | Bound | Default |
|---|---|---|---|
| `view` | repeated string | ≤ `MAX_VIEWS` = 4 items, ≤ 64 chars each | empty → the **selection rule** decides |
| `currency` | enum | `USD` | `USD` |
| `precision` | int | 0 ≤ n ≤ 8 | the projection's own default |
| `locale` | enum | `en-US`, `es-AR`, `de-DE` | `en-US` |
| `sort` | enum | `value_desc`, `value_asc`, `label` | `value_desc` |
| `top_n` | int | 1 ≤ n ≤ 20 | 5 |
| `include_other` | bool | — | `true` |
| `fields` | repeated string | ≤ 8 items, ≤ 32 chars each | all sections |

A supplied option that the **requested projection does not declare** is also a
**422** (`validation-failed`), because every options model is
`extra="forbid"`: `?view=attribution.waterfall.v1&top_n=3` is rejected, since
the waterfall declares no `top_n`. This is ADR-K D-3 — nothing is interpreted
at runtime, nothing is silently ignored.

**Response** (`PortfolioViewsResponse`), a keyed object (ADR-K D-17):

```json
{
  "as_of": "2026-01-15T12:00:00Z",
  "portfolio_id": "current",
  "views": {
    "holdings.allocation.v1": { "view": "holdings.allocation.v1", "...": "…" },
    "attribution.waterfall.v1": { "view": "attribution.waterfall.v1", "...": "…" }
  }
}
```

Each value is a member of the **discriminated union** built from the registry:
`oneOf` with `discriminator.propertyName = "view"` and one OpenAPI example per
registered projection, attached to the operation's `200` response. The union,
the mapping and the examples are **derived from the registry**, never written
by hand — that is what makes D-15 true rather than aspirational.

**Projection ids and their payloads**

| Id | Purpose | Declared options | DTO |
|---|---|---|---|
| `holdings.allocation.v1` | Allocation by holding: weight and market value per symbol, with a residual `Other` bucket | `currency`, `precision`, `sort`, `top_n`, `include_other` | `title`, `total: Total`, `categories: tuple[Category, …]` |
| `attribution.waterfall.v1` | Unrealised P/L from cost basis to market value, one bucket per holding | `currency`, `precision`, `locale`, `fields` | `title`, `start: Total`, `end: Total`, `buckets: tuple[Bucket, …]`, `annotations: tuple[Annotation, …]` |

**Every number is a pre-formatted `*Display` string** (ADR-K D-5, ADR-E D-2/D-3)
carried next to its exact `Decimal` for charting: `MoneyDisplay(amount,
display)` and `PercentageDisplay(value, display)`. The client never rounds,
never formats and never computes a percentage.

**Selection rule** (ADR-K D-13). When no `view` is supplied, each registered
projection scores itself against the data through `fitness(portfolio)` and the
highest score wins, ties broken by ascending id so the demo is reproducible.
When every projection scores `0` the endpoint's documented default
(`holdings.allocation.v1`) is used. Today:

- `attribution.waterfall.v1` scores **2** when the portfolio holds both a
  winner and a loser — there is a move to explain;
- `holdings.allocation.v1` scores **1** whenever there is at least one
  holding — it always fits;
- an empty portfolio scores `0` everywhere and falls back to the default.

The rule lives in `presentation/selection.py` and needs no edit when a chart is
added: the new module declares its own `fitness`.

**Render intent** (ADR-K D-11/D-12), no HTTP surface of its own:
`RenderIntentService.render(subject, intent, default=…)` takes
`RenderIntent(view, options)`, resolves it through the **same** registry and
the **same** options models, and on rejection increments
`presentation.render_intent.rejected` on the injected `ErrorReporter` and
renders the endpoint default instead. It returns
`RenderedIntent(view, payload, surface, rejection)` so GGU-47 can stream the
surface and log why a fallback happened. The model picks; it never invents.

`RenderIntentService.accept(view=…, options=…, default=…)` is the same verdict
without the payload, and it is what the **agent turn** calls (GGU-84, through
`services/agent_renders.TurnRenderResolver`, from `services/agent_tools.py`).
It returns `AcceptedIntent(view, options, rejection)`. The split exists because
a turn must judge every surface it emits while the wire still carries only
`{view, options}`: rendering a payload per intent would cost a portfolio read
each time and throw the result away. `render` is `accept` followed by the
render, so there is one verdict and one place it can change.

**This was written down long before anything called it.** Between GGU-47 and
GGU-84 the enforcement above existed, was unit-tested, had a `Depends`
provider — and no call site, so what actually guarded a tool-emitted view id
was `VIEW_ID_SHAPE`, a regex `totally.invented.v9` satisfies, and options were
never judged at all. A provider looks wired by virtue of existing; the seam is
where the hole was.

**Layering.** `app/presentation/` is an inner layer beside `app/domain/`: it
imports stdlib, pydantic, `app.core` and `app.domain` only, and nothing from
`api`, `services`, `repositories`, `models`, `infra` or `auth`. `app/schemas/views.py`
imports the projection DTO base from `presentation.fragments` — the envelope is
a schema, the payloads are the presentation layer's, and a test enforces the
boundary.

## 4. Data model & migration

**No tables, no migration, no Alembic revision.** Projections are pure
functions over the in-memory portfolio (spec 0003, ADR-F D-1). The only
composition-root change is one new `Container` field, `portfolio:
PortfolioProvider`, built in `bootstrap.build_container` from the injected
`Clock` — the process-wide provider spec 0003 AC-8 requires, so `as_of` stays
fixed per subject for the life of the process.

| Module | Holds |
|---|---|
| `presentation/formatting.py` | `money_display`, `percentage_display`, `quantity_display` — the single `Decimal` → string boundary (ADR-E D-2/D-3), locale-aware |
| `presentation/fragments.py` | `ProjectionDto`, `Surface`, `MoneyDisplay`, `PercentageDisplay`, `Category`, `Bucket`, `SeriesPoint`, `Series`, `Total`, `Annotation` |
| `presentation/options.py` | `ProjectionOptions` (`extra="forbid"`), `CurrencyOptions`, `PrecisionOptions`, `LocaleOptions`, `SortOptions`, `TopNOptions`, `FieldSelection` |
| `presentation/registry.py` | `Projection` Protocol, `ProjectionSpec`, `ProjectionRegistry`, `REGISTRY`, `register` |
| `presentation/selection.py` | `select_view` — the no-preference rule |
| `presentation/prompt.py` | `prompt_fragment` — the registry rendered as the text GGU-14 feeds the model |
| `presentation/contract.py` | `payload_annotation`, `views_response_model`, `response_examples` — the registry rendered into OpenAPI |
| `presentation/sample.py` | `EXAMPLE_AS_OF`, `sample_portfolio` — the fixed instant every example is rendered at |
| `presentation/views/holdings_allocation.py` | id, options, DTO, `render`, A2UI adapter, `fitness`, `register(...)` |
| `presentation/views/attribution_waterfall.py` | the same, for the waterfall |
| `schemas/views.py` | `ViewQuery`, `ViewDescriptor`, `PortfolioViewsResponse`, `RenderIntent` |
| `services/view_service.py` | `ViewService` — resolve ids, validate options, render, build the catalog |
| `services/render_intent_service.py` | `RenderIntentService` — the agent path with telemetry and fallback |
| `api/v1/views.py` | `GET /v1/views` |
| `api/v1/portfolio_views.py` | `GET /v1/portfolios/{portfolio_id}/views` |

**Examples are rendered, not written.** Every OpenAPI example and every
catalog example payload is produced by running the projection itself over
`sample_portfolio()` — the seeded demo portfolio at a fixed literal instant.
A hand-copied example can drift from the DTO; a rendered one cannot.

## 5. Security notes

- **Auth**: both routes require a verified bearer token through `PrincipalDep`;
  neither is public. `GET /v1/views` is a catalog of shapes, never of data.
- **Authorization**: the portfolio route resolves the portfolio from the
  authenticated `principal.subject`; `portfolio_id` is only accepted as the
  well-known `current`, so no caller can name another subject's portfolio.
- **Input**: every option is declared, bounded and defaulted; `extra="forbid"`
  on the query model and on every options model means an undeclared or
  out-of-range value is rejected with a 422 rather than best-effort guessed.
  There is no template, expression or field path interpreted from client or
  model input (ADR-K D-3) — the free-form projection DSL is a rejected
  alternative precisely because it is an injection and denial-of-service
  surface.
- **Denial of service**: `MAX_VIEWS = 4` caps the work one request can ask for;
  `top_n ≤ 20` and `fields ≤ 8` cap each render. The existing body-size limit
  and per-token rate limit still apply.
- **Error masking**: rejections answer RFC 9457 problem documents through the
  existing handler; the detail names the offending option, never the raw input
  value, and never a stack trace.
- **Telemetry / no PII**: a rejected render intent increments a counter with
  the view id as a tag. The subject is never a tag and never logged here; the
  portfolio data is simulated and carries no PII (spec 0003 §5).
- **Feature flags**: both routes are gated with `require_feature("views.read")`
  / `require_feature("views.catalog")` (default `True`), so a broken projection
  can be switched off in the demo without a deploy.

Maps to `backend/docs/SECURITY.md` — no new control is claimed, no existing one
is weakened.

## 6. Acceptance criteria

1. **AC-1** A `Projection` Protocol declares id, one-line summary, serving
   endpoints, options model, DTO type, example, pure `render`, A2UI adapter and
   `fitness`; `ProjectionSpec` implements it and `register(...)` is called from
   the projection's own module. Importing `app.presentation.views` is what
   wires them (ADR-K D-7).
2. **AC-2** `fragments.py` provides the reusable DTO primitives (series,
   bucket, category, total, annotation, money/percentage `*Display` pairs) and
   both reference projections are built from them (ADR-K D-16).
3. **AC-3** `options.py` provides reusable bounded option mixins (locale,
   currency, precision, field selection, sort, `top_n`); every field is
   described with examples and bounded, and every options model forbids extras.
4. **AC-4** `holdings.allocation.v1` renders the seeded portfolio into a
   titled total plus one category per holding, honours `sort`, `top_n` and
   `include_other` (residual bucket), and every number it emits is a
   pre-formatted `*Display` string next to its exact `Decimal`.
5. **AC-5** `attribution.waterfall.v1` renders cost basis → market value with
   one bucket per holding, a running cumulative, direction per bucket and
   annotations, honours `locale`, `precision` and `fields`, and an unknown
   `fields` section is rejected with a 422 naming it.
6. **AC-6** `GET /v1/portfolios/current/views?view=a&view=b` answers **one
   keyed object with both entries** in a single request, each value carrying
   its `view` discriminator; the OpenAPI operation documents the response as
   `oneOf` with a `discriminator` and one example per registered projection.
7. **AC-7** An **undeclared** query parameter, an **out-of-range** option, more
   than `MAX_VIEWS` views and an option the requested projection does not
   declare each answer **422** as an RFC 9457 problem document; an unknown view
   id answers **404** `portfolio/unknown-view`.
8. **AC-8** `GET /v1/views` lists every registered projection with its id,
   summary, serving endpoints, options JSON schema and an example payload that
   validates against that projection's DTO.
9. **AC-9** `RenderIntentService.render` validates `{view, options}` against
   the same registry; a rejected intent is recorded through the injected
   `ErrorReporter` and answered with the endpoint's default projection, with
   the rejection reason carried on the result. An accepted intent renders the
   requested view and reports nothing. **The agent turn calls this** (GGU-84):
   every render intent a tool emits is judged before it reaches the client,
   and a rejection falls back rather than failing the turn.
10. **AC-10** With no `view` supplied, the documented selection rule picks from
    the data: the seeded portfolio (winners **and** losers) selects
    `attribution.waterfall.v1`; a portfolio of winners only selects
    `holdings.allocation.v1`; an empty portfolio falls back to the endpoint
    default. The rule ranks by `fitness`, ties broken by ascending id.
11. **AC-11** `prompt_fragment(...)` renders the registry into the text GGU-14
    feeds the model — id, one-line purpose and declared options with their
    bounds — generated from the registry and the options JSON schema, never
    hand-copied.
12. **AC-12** `tests/unit/api/test_openapi_contract.py` fails when a registered
    projection has no OpenAPI example, no options schema in the catalog, or a
    `view` field that is not a `Literal` equal to its id.
13. **AC-13** **Extensibility is proven, not claimed**: a test defines a brand
    new projection *inside the test*, registers it, and sees it appear in the
    registry, in `GET /v1/views` and in the generated prompt fragments —
    without editing any shared file (ADR-K D-15).
14. **AC-14** `app/presentation/` imports nothing from `api`, `services`,
    `repositories`, `models`, `infra` or `auth`, and never reads a wall clock —
    enforced by a test that greps the package (ADR-K D-6).
15. **AC-15** `make gate` stays green: ruff, basedpyright strict, the 150-line
    budget, `make quality`, pytest at 100 % branch coverage, pip-audit.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/presentation/test_registry.py::test_register_publishes_the_projection`, `::test_register_rejects_a_duplicate_id`, `::test_registry_get_rejects_an_unknown_id`, `::test_projection_spec_satisfies_the_protocol` | — |
| AC-2 | `tests/unit/presentation/test_fragments.py::test_money_display_pair_carries_the_exact_decimal`, `::test_surface_is_frozen`, `test_holdings_allocation.py`, `test_attribution_waterfall.py` | — |
| AC-3 | `tests/unit/presentation/test_options.py::test_every_option_field_is_described_and_bounded`, `::test_options_reject_an_undeclared_field`, `::test_field_selection_rejects_an_unknown_section` | — |
| AC-4 | `tests/unit/presentation/test_holdings_allocation.py::test_render_lists_one_category_per_holding`, `::test_render_honours_top_n_with_a_residual_bucket`, `::test_render_drops_the_residual_bucket_when_not_wanted`, `::test_render_honours_sort` (ids `value_desc`, `value_asc`, `label`), `::test_every_number_is_displayed_and_exact` | — |
| AC-5 | `tests/unit/presentation/test_attribution_waterfall.py::test_render_walks_cost_basis_to_market_value`, `::test_render_marks_direction_per_bucket`, `::test_render_honours_locale` (ids `en-US`, `es-AR`, `de-DE`), `::test_render_trims_unselected_sections`, `::test_render_rejects_an_unknown_section` | — |
| AC-6 | `tests/unit/api/test_views_endpoints.py::test_two_views_are_rendered_in_one_request`, `::test_response_documents_a_discriminated_union_with_one_example_per_view` | `tests/integration/test_views_flow.py::test_portfolio_views_returns_two_projections_in_one_request` |
| AC-7 | `tests/unit/api/test_views_endpoints.py::test_bad_option_is_a_problem_document` (ids `undeclared-parameter`, `out-of-range`, `too-many-views`, `option-the-view-does-not-declare`), `::test_unknown_view_id_is_404` | `tests/integration/test_views_flow.py::test_out_of_range_option_is_422` |
| AC-8 | `tests/unit/api/test_views_endpoints.py::test_catalog_describes_every_registered_projection`, `tests/unit/presentation/test_contract.py::test_every_example_validates_against_its_dto` | `tests/integration/test_views_flow.py::test_catalog_is_served` |
| AC-9 | `tests/unit/services/test_render_intent_service.py::test_accepted_intent_renders_the_requested_view`, `::test_a_rejected_intent_falls_back_and_is_reported`, and — at the seam, over the registry (GGU-84) — `tests/unit/services/test_agent_render_intents.py::test_a_registered_view_reaches_the_client_unchanged`, `::test_a_view_the_registry_never_heard_of_falls_back_to_the_default`, `::test_an_option_a_known_view_refuses_falls_back_too` | — |
| AC-10 | `tests/unit/presentation/test_selection.py::test_selection_prefers_the_waterfall_when_the_portfolio_has_a_loser`, `::test_selection_falls_back_to_allocation_without_a_loser`, `::test_selection_uses_the_endpoint_default_when_nothing_fits`, `::test_selection_breaks_ties_by_id`, `::test_selection_uses_the_default_for_an_empty_registry` | — |
| AC-11 | `tests/unit/presentation/test_prompt.py::test_fragment_lists_every_projection_with_its_options`, `::test_fragment_is_generated_from_the_registry` | — |
| AC-12 | `tests/unit/api/test_openapi_contract.py::test_every_projection_has_an_openapi_example`, `::test_every_projection_dto_declares_its_discriminator_literal`, `::test_every_projection_publishes_an_options_schema` | — |
| AC-13 | `tests/unit/presentation/test_extensibility.py::test_a_projection_defined_in_a_test_reaches_every_consumer` | — |
| AC-14 | `tests/unit/presentation/test_package_boundaries.py::test_presentation_has_no_outward_imports`, `::test_presentation_never_reads_the_wall_clock` | — |
| AC-15 | `make gate` | — |

Mutation checks required (auth / rate limit / error masking): **no** — this
ticket adds no authentication, rate limiting or masking behaviour; it consumes
the existing `PrincipalDep` and the existing RFC 9457 handler. The equivalent
mutation check here is AC-7 and AC-13: AC-7's four rejection cases are what
prove the options models can fail at all (an options model without
`extra="forbid"` would pass every positive test forever), and AC-13 is what
proves the registry seam is real rather than a shared list in disguise.

**Guardrail carried from ADR-K:** a projection that needs a shared file edited
to exist is a failed implementation. If a future chart cannot be added by
adding one module, the seam is fixed — the chain is never extended.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Where do per-view options travel on a multi-view request? | TL | **Resolved:** shared, documented query parameters applied to every requested view; each projection validates the subset it declares and rejects the rest (`extra="forbid"`). Per-view option namespacing would need a nested query syntax — an interpreter in the query string, which ADR-K D-3 rejects. `POST /v1/view-renders` (D-18, out of scope) is where per-entry options belong |
| OD-2 | Schema-level or operation-level OpenAPI examples? | Implementer | **Resolved:** operation-level, keyed by view id on the `200` response, **rendered from the registry**. A schema-level `json_schema_extra` example must exist before the DTO class is complete, which forces it to be hand-copied — exactly the drift ADR-K D-14 forbids |
| OD-3 | How does the selection rule stay additive (D-13 vs D-15)? | Implementer | **Resolved:** each projection declares its own `fitness(portfolio)`; the rule ranks the registry instead of branching on ids. The endpoint default remains an endpoint-level constant, as D-2 requires |
| OD-4 | Does `currency` have to convert? | TL | **Resolved:** no. The portfolio is denominated in USD and the backend invents no FX rate (numbers-from-tools). `currency` is declared as `Literal["USD"]`: bounded, documented, and a request for `EUR` is an honest 422 rather than a fabricated figure. Widening it is additive when a rate source exists |
| OD-5 | Where does the response envelope DTO live? | Implementer | **Resolved:** `app/schemas/views.py`, importing the projection DTO base from `presentation.fragments`. The envelope is HTTP's; the payloads are the presentation layer's. `ViewQuery` lives there too, so the endpoint's parameter contract is one documented model |
| OD-6 | How is the portfolio provider reached from a controller? | Implementer | **Resolved:** one new `Container` field built in `bootstrap.build_container` (the single composition root) and one `deps.py` provider. A lazy singleton on `app.state` would keep the composition root untouched but put construction in the dependency layer, which `.claude/rules/backend/architecture.md` forbids |
| OD-7 | Which portfolio ids does the route accept? | TL | **Resolved:** only the well-known `current`, resolved from the authenticated subject; anything else is a 404. A caller must not be able to name another subject's portfolio, and ADR-F gives no other id yet |

## 9. Rollout & observability

Both routes ship behind feature flags that default to **on**
(`views.catalog`, `views.read`), so a projection that misbehaves in the demo is
switched off with `PUT /v1/admin/feature-flags/{key}` rather than a deploy.
No migration, no data change, no client contract broken: the package is new and
nothing else reads it yet.

Observability: `RenderIntentService` increments
`presentation.render_intent.rejected` (tag `view`) whenever the model asks for
something the registry refuses, which is the signal GGU-14 needs to tell
whether the prompt fragments actually teach the catalog. Renders themselves are
not logged — at tool-call frequency that is noise, and the projections are pure,
so a payload is reproducible from `(as_of, view, options)` alone. Sentry
expectations are unchanged: a rejected option is an expected `AppError` → 422,
never an unhandled exception.
