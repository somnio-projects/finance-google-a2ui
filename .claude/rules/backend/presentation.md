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

`views/<name>.py` is the **only** file a new chart touches. If adding a chart
makes you edit `registry.py`, an enum, a union list or an `if/elif`, the design
is wrong — fix the seam, do not extend the chain (ADR-K D-15).

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

## 4. The registry feeds four consumers

Registering once publishes the projection to: the **OpenAPI** document, the
**`GET /v1/views` catalog** (id, serving endpoints, options schema, example),
the **prompt fragments** that teach the model the catalog (generated, never
hand-copied), and the **A2UI surface** adapter for the genui client. `genui`,
`genui_a2a` and `a2ui_core` are alpha: keeping the A2UI mapping in one adapter
per projection is what makes a library bump a contained change.

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
- [ ] Appears in `/v1/views`, in OpenAPI with an example, and in the generated prompt fragments.
- [ ] Spec updated (`specs/backend/NNNN-*.md`) and the decision recorded if anything in ADR-K changed.
