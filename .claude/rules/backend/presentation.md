# Presentation layer rules — projections, options and A2UI surfaces

Enforces [ADR-K](../../../docs/adr/ADR-K-response-shaping.md). Everything the
client renders is shaped **here**, in `backend/src/app/presentation/`. The
Flutter client binds what it receives; it never maps, never formats, never
computes.

## 1. What a projection is

A projection is a **pure function** *(domain result, options) → DTO*, registered
under a versioned id `"<component>.<variant>.v<N>"` (`attribution.waterfall.v1`).
It lives in its own module with everything it needs:

```
presentation/
  registry.py              the registry + the Projection Protocol (shared, rarely touched)
  fragments.py             reusable DTO pieces: Series, Bucket, Category, Total, MoneyDisplay…
  options.py               reusable option mixins: LocaleOptions, PrecisionOptions, FieldSelection
  views/
    attribution_waterfall.py   id + options model + DTO + render() + A2UI adapter + register()
    holdings_allocation.py     …
```

A new chart **edits no existing file**. If adding one makes you touch
`registry.py`, an enum, a union list or an `if/elif`, the design is wrong —
fix the seam, do not extend the chain (ADR-K D-15).

It may **create** more than one. `views/<name>.py` holds the projection and
its `register(...)`, and for a simple chart that is the whole of it; a chart
whose options are a domain object in their own right will not fit its DTO,
options model and builders into 150 lines, and the budget is a gate while
"one module" is a preference. All four charts added by GGU-41 split three or
four ways. The helpers sit **beside** `views/`, not inside it —
`tests/unit/presentation/test_package_boundaries.py` requires exactly one
`register(...)` per module in that package, which is what keeps discovery
unambiguous. Name them after the view (`taxlots.py`, `taxlot_scenario.py`,
`taxlot_render.py`) so the group is obvious in a directory listing.

## 2. The rules that are checked in review

- **Pure.** No I/O, no repository, no session, no clock reads — the clock and the data arrive as arguments. A business rule that sneaks into a presenter belongs to the domain or a service.
- **Declared options only.** Every knob is a field on the projection's pydantic options model: bounded (`ge`/`le`/`max_length`/`Literal`), defaulted, described, exemplified. Unknown or out-of-range options are a **422**, never a best-effort guess. No free-form template, expression or field path is ever interpreted from client or model input (ADR-K D-3).
- **Every number is pre-formatted.** `*Display` strings produced server-side under [ADR-E](../../../docs/adr/ADR-E-money-representation.md); raw `Decimal` may accompany them for plotting, never replace them.
- **Discriminated.** Every DTO carries `view: Literal["<id>"]`; endpoint `response_model`s are unions with a `discriminator`, and each member ships an OpenAPI example.
- **Registered locally.** `register(...)` is called from the view's own module; importing the `views` package is what wires them (one import line in the package `__init__`, added by the module's own PR).
- **Reuse the fragments.** Build from `fragments.py`; a genuinely new primitive is added there, with tests, in the same PR (ADR-K D-16).
- **≤150 lines per file**, docstring on every public symbol, 100 % branch coverage — the normal gate.

## 3. Two callers, one path

| Caller | How it asks | What validates it |
|---|---|---|
| Flutter client | `?view=<id>` + declared options (the endpoint has a default) | FastAPI + the options model |
| The agent / model | a **render intent** `{view, options}` in its tool call | the same registry and the same options model — an unknown view or option is rejected, telemetry records it, and the endpoint's default projection is used instead (ADR-K D-11, D-12) |

The model **picks** from the registry; it never invents a shape, never adds a
field and never supplies a formatted number. When neither caller expresses a
preference, the endpoint's documented **selection rule** chooses from the data,
and that rule is tested (ADR-K D-13).

## 4. The registry feeds five consumers

Registering once publishes the projection to: the **OpenAPI** document, the
**`GET /v1/views` catalog** (id, serving endpoints, options schema, example),
the **prompt fragments** that teach the model the catalog (generated, never
hand-copied), the **A2UI surface** adapter for the genui client, and the
**frozen design contract** — the field inventory design binds to (GGU-41, spec
`backend/0019`), also generated. `genui`, `genui_a2a` and `a2ui_core` are
alpha: keeping the A2UI mapping in one adapter per projection is what makes a
library bump a contained change.

The contract is published in **two renderings, from one render pass**
(`presentation/catalog_artifacts.py`):

| Artefact | For | Carries |
|---|---|---|
| [`docs/catalog/CONTRACT.md`](../../../docs/catalog/CONTRACT.md) | the designer | options, field inventory, example, digest |
| [`docs/catalog/view-catalog.snapshot.json`](../../../docs/catalog/view-catalog.snapshot.json) | the Flutter catalog test (GGU-53, spec `backend/0021`) | **component type**, view id, field paths, options schema, example, digest |

A third rendering is one entry in `ARTIFACTS` plus its renderer — never a
second script and never a second gate step.

Both are **gated**: `make gate` re-renders them and diffs them, so a projection
cannot change without the artefacts changing in the same commit. After touching
a projection, run `cd backend && make catalog` and commit the result. The
component name in the snapshot is read from the projection's own A2UI adapter
and is what the client registers against, verbatim — rename it and the gate
fails on both the snapshot and the suite.

**A drift check cannot tell you the generator is wrong.** Each artefact is
re-rendered and diffed against *its own* generator, so both can be green while
both disagree with design — which is exactly what GGU-53 found: four of six
component names were wrong, and the Markdown contract did not print the
component name at all. Re-rendering proves an artefact is *current*, never that
it is *right*. Only a second, independent declaration can do that, which is why
`test_component_names.py` holds design's six names as a literal and compares
them against the adapter, the snapshot, the Markdown and `/v1/views`.

**A design page's guidance is prompt text, so audit it before transcribing
it.** A Zone 3 fragment is generated into the catalog the model reads, so a
sentence in it that tells a reader to work a figure out is the
numbers-from-tools invariant broken in the one place built to teach the model
the rules. Read every fragment against that question before it ships, and
record the ones you decline rather than dropping them silently — spec 0024 §5
is the worked example: the `OrderTicket` page says the component *"recomputes
weights, cash and shares live as parameters change"*, which is exactly what
`effect: "recalculate"` does **not** mean. A fragment is design-owned prose,
and this is the one thing it is not free to say.

**A gallery-card name is provisional.** Where a component's detail page was
never exported, its gallery card is the only declaration it has and therefore
wins — as a *fallback*, not a tie-break. When the page arrives, the name is
decided again from its own Zone 2 block, and it may move: two of three did on
2026-09-21 (spec 0024 §2). The day a page lands is the day to revisit
`docs/catalog/design/README.md`, not the day somebody notices the client
registering a widget under a name design never wrote.

**Before removing a field nothing appears to bind, read the clients.** A field
nobody binds is a field nobody maintains, so it goes — but "nothing binds it"
is a claim about code that exists, including open pull requests. `price` and
`remaining[]` left `taxlots.table.v1` under spec 0024 §7; `cost_basis` and
`proceeds` stayed, because the component binds their **labels** as column
captions (a Dart constant there would not follow the `locale` option). A
`label` is a binding.

Two conventions the contract reads:

- **Pre-formatted** is derived from the ADR-E pair (a string beside a figure),
  not from the `display` name — keep shipping pairs and it classifies itself.
- **An editable field is a payload field named exactly as the option that sets
  it.** That naming *is* the interactivity declaration; a component with an
  input that does not round-trip through a declared option breaks D-3.

## 5. Delivery speed is part of the contract

| Need | Mechanism |
|---|---|
| Several widgets at once, one round trip | repeated `?view=` on a read endpoint (capped, documented) → keyed object, one entry per view: one auth, one session, one domain build, *N* pure renders |
| Widgets across different resources | `POST /v1/view-renders` — the batch is a resource; per-entry status so one failure does not sink the rest |
| First pixel as early as possible | inside an agent turn, surfaces stream as they are ready (ADR-D) |
| Repeat reads | strong `ETag` from *(resource version, view, options, `as_of`)* + `Cache-Control`; 304 on revalidation; in-process memoisation of the domain build per session and of each render per options hash |
| Payload size | the `fields` option trims what the widget does not bind; raw `Decimal` only when asked for; compression at the edge |

**Budget:** p95 **< 150 ms** warm, **< 400 ms** cold, **< 1 s** to the first
streamed surface. Heavy work belongs in the domain (precomputed at seed time),
never in a presenter and never in the client. A projection that misses the
budget is a defect like a failing test.

## 6. Adding a chart — the checklist

- [ ] New module under `presentation/views/`, id versioned `v1`.
- [ ] Options model: bounded, defaulted, described, with examples.
- [ ] DTO built from `fragments.py`, `view` literal, every number `*Display`.
- [ ] `render()` pure and unit-tested, including every option branch and the empty/edge data cases.
- [ ] A2UI adapter + its test.
- [ ] `register(...)` called from the module; nothing else edited.
- [ ] **The component name comes from the design catalog**, and the new view is added to `DESIGN_CATALOG` in `tests/unit/presentation/test_component_names.py`. That file is red until you do, on purpose (spec 0023, superseding 0019/0021's "never assert the list"): it is the only inventory in the suite not read from the registry, because it is design's half of the contract rather than a copy of ours. A component nobody has named is a component the client cannot register.
- [ ] Guidance (`use_when` / `avoid_when`) **if design has written a page for it**, in `<view>_guidance.py`. If not, leave it unset — the contract prints that the page does not exist, and a sentence invented here would be indistinguishable from one a designer approved.
- [ ] Appears in `/v1/views`, in OpenAPI with an example, and in the generated prompt fragments.
- [ ] `cd backend && make catalog` run and **both** `docs/catalog/CONTRACT.md` and `docs/catalog/view-catalog.snapshot.json` committed — the gate fails on a stale artefact, twice.
- [ ] Spec updated (`specs/backend/NNNN-*.md`) and the decision recorded if anything in ADR-K changed.
