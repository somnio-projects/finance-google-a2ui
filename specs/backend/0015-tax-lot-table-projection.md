# 0015 — `tax_lots.table.v1`: the lots a proposed sale consumes, short and long

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) · **Related:** 0005 (presentation layer), 0013 (`simulate_sale`), 0003 (domain), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md) · rule `.claude/rules/backend/presentation.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow B ends on a **tax-lot table**: the user asks what selling part of a
position would cost them, and the answer is a table of lots — which ones the
sale eats, when each was bought, whether each is short- or long-term, and what
each realises — under a summary that splits the realised result by holding
period.

The finance already exists. `simulate_sale` (spec 0013) walks the lots and
`SaleSimulation` carries the result. What does not exist is a **surface**: spec
0013 OD-5 deliberately left the tool emitting **no render intent**, because
pointing at a view that is not registered is the same lie as inventing a
number, and `tax_lots.table.v1` "arrives with the component, not ahead of it".

This spec is that component. It registers one projection so the sale scenario
can be rendered by the client (`?view=`), by the agent (a render intent) and by
the batch endpoint, through the one registry ADR-K D-11 requires.

The hard part is not the table. It is that every other registered projection
renders **the portfolio**, and this one renders **a sale** — a domain result the
portfolio does not contain and cannot be asked for without naming a scenario.
§8 OD-1 is that question and its answer; the rest of the spec follows from it.

## 2. Scope

**In**

- `app/presentation/views/tax_lots_table.py` — the projection: id, pure
  `render`, A2UI adapter, `fitness`, and its own `register(...)`.
- `app/presentation/tax_lots.py` — what the payload **is**: `TaxLotRow`,
  `TermTotal`, `TaxLotsTablePayload`.
- `app/presentation/tax_lot_scenario.py` — what the projection **accepts**:
  `TaxLotsTableOptions` and the scenario's bounds.
- `app/presentation/tax_lot_render.py` — the pure builders that fill the DTOs.
  Four modules rather than one because the 150-line budget forces the split
  (OD-7), taken along the seams spec 0013 already cut through the same data:
  what the answer **is**, what was **asked for**, and how it **reads**.
- `app/schemas/views.py` — one character class in `VIEW_ID_PATTERN`, so the
  ticket's id is reachable by the callers at all (OD-2).
- Tests for all of the above.

**Out**

- **Emitting the render intent from `simulate_sale`.** The tool now has a view
  to point at, but pointing at it is a change to the tool's contract and to
  spec 0013 OD-5. It is one line in `app/agent/tools/simulate_sale.py` and it
  belongs to that module's own ticket, not to this one (OD-8).
- **A dollar-sized scenario (`amount_usd`).** The projection takes units. A
  dollar size is resolved against the price by `simulate_sale`, and the model
  copies the units it returned rather than dividing (OD-4).
- **Committing the sale.** Read-only, like the domain walk it renders.
- **Tax rates, a tax bill, wash sales, fees.** The split is reported, never
  applied to. Unchanged from spec 0013.
- **Comparing two lot methods side by side.** One scenario per render; a
  comparison is two entries in one `POST /v1/view-renders` batch, which is
  exactly what ADR-K D-18 is for.

## 3. API contract

No new route. The projection is served by the endpoints every portfolio
projection is served by (`app.presentation.endpoints.PORTFOLIO_ENDPOINTS`):

| Caller | How it asks | What validates it |
|---|---|---|
| Flutter client | `GET /v1/portfolios/current/views?view=tax_lots.table.v1` | `ViewQuery` + the options model |
| The agent | a render intent `{view: "tax_lots.table.v1", options: {...}}` | the same registry, the same options model |
| A batch | one entry of `POST /v1/view-renders` | the same |

**Declared options.** Bounded, defaulted, described and exemplified; anything
else is a 422 (`extra="forbid"`, ADR-K D-3).

| Option | Type | Bound | Default | What it names |
|---|---|---|---|---|
| `symbol` | string | `^[A-Za-z]{2,10}$`, ≤ 10 | `BTC` | the position being sold |
| `quantity` | string | `^\d{1,12}(\.\d{1,8})?$` | `0.5` | units to sell, as a **decimal string** (OD-3) |
| `lot_method` | enum | `FIFO`, `LIFO`, `HIFO` | `FIFO` | which lots the sale eats first |
| `currency` | enum | `USD` | `USD` | from `CurrencyOptions` |
| `precision` | int | 0..8 | 2 | from `PrecisionOptions`; does not apply to the unit price (OD-5) |
| `locale` | enum | `en-US`, `es-AR`, `de-DE` | `en-US` | from `LocaleOptions` |
| `fields` | list | ≤ 8 names, from `lots`, `remaining` | all | from `FieldSelection`; the split is **not** trimmable (OD-6) |

**Payload** (`TaxLotsTablePayload`, discriminated by `view`):

| Field | Type | What it carries |
|---|---|---|
| `view` | `Literal["tax_lots.table.v1"]` | the discriminator |
| `title` | str | "Tax lots this sale consumes" |
| `subtitle` | str | the scenario in words: "Sell 0.5 BTC under FIFO" |
| `price` | `Total` | the unit price, at the precision it is quoted to (OD-5) |
| `proceeds` | `Total` | what the sale raises |
| `cost_basis` | `Total` | what the consumed units cost |
| `realized` | `Total` | `proceeds − cost_basis`, signed |
| `by_term` | `tuple[TermTotal, ...]` | **one entry per `LotTerm`, always** (OD-6) |
| `lots` | `tuple[TaxLotRow, ...]` | one row per consumed lot, in consumption order |
| `remaining` | `tuple[Annotation, ...]` | the position left over, as labelled figures |

`TaxLotRow` = `label` (the lot id), `acquired_on`, `term`, `units`,
`cost_basis`, `proceeds`, `gain_loss`, `trend`, `fully_sold`.
`TermTotal` = `label` ("Short-term"), `term`, `lots` (a count), `realized`.

**Every figure is a pre-formatted string.** Money travels as `MoneyDisplay`
(exact `Decimal` + string); a gain or loss uses `signed_money_display`, so
`+$8,925.00` and `-$1,200.00` cannot be confused; the unit price uses
`price_display`, which carries four decimals when cents are not enough — DOGE
is quoted at `$0.1273` and `$0.13 × 12,000` misses the proceeds printed beside
it by $32.40 (spec 0013 OD-4). `units` is a plain pre-formatted string: nothing
plots a lot's unit count, so it needs no exact-`Decimal` twin (OD-9).

**Errors.** `render` calls a domain function, so it can fail on the *data*
rather than on the options (OD-1):

| Condition | Error | Status |
|---|---|---|
| ticker not in the curated market | `SymbolNotFoundError` | 404 `portfolio/unknown-symbol` |
| position holds fewer units | `PositionTooSmallError` | 422 `portfolio/position-too-small` |
| quantity resolves to zero | `SaleQuantityError` | 422 `portfolio/invalid-sale-quantity` |

All three are existing `AppError`s, so the HTTP path renders them as RFC 9457
through the handler that is already there, and the agent path falls back to the
default projection with the rejection recorded — `RenderIntentService` catches
`AppError`, not `ValidationFailedError` specifically, so this needed no change.

## 4. Data model & migration

**None.** No table, no column, no Alembic revision. The projection is a pure
function over the in-memory portfolio.

| Module | Holds |
|---|---|
| `presentation/tax_lots.py` | `TaxLotRow`, `TermTotal`, `TaxLotsTablePayload`, `TERM_LABELS` |
| `presentation/tax_lot_scenario.py` | `TaxLotsTableOptions`, `SIZE_PATTERN`, the default scenario |
| `presentation/tax_lot_render.py` | `signed_money`, `price_total`, `units_of`, `lot_row`, `term_split`, `remaining_notes`, `subtitle` |
| `presentation/views/tax_lots_table.py` | id, summary, `SECTIONS`, `render`, `surface`, `fitness`, `register(...)` |

## 5. Security notes

- **Auth / authorization**: unchanged. The projection is reached only through
  routes that already require a bearer token and resolve the portfolio from
  the authenticated subject; nothing here names a subject.
- **Input**: three new options, all bounded — a ticker by pattern and length,
  a size by a pattern that caps it at 12 integer and 8 fractional digits, a
  method by `Literal`. The size bound is what stops the option being used to
  make the lot walk do work proportional to the input; the walk itself is
  bounded by the lots the portfolio holds, which is seed data.
- **No interpretation**: no template, no expression, no field path. A
  `quantity` is parsed with `Decimal(...)` after the pattern has already
  proved it is digits.
- **Error masking**: `PositionTooSmallError` keeps the quantities as
  attributes and out of its message on purpose (spec 0013 §5) — how much of a
  symbol someone holds does not belong in an RFC 9457 body. This projection
  does not catch it and does not re-render it; the 422 says only that the
  position holds fewer units.
- **Denial of service**: no new unbounded field, no new loop. `MAX_VIEWS` and
  the batch cap still bound how many renders one request can ask for.

Maps to `backend/docs/SECURITY.md` — no new control claimed, none weakened.

## 6. Acceptance criteria

1. **AC-1** `tax_lots.table.v1` is registered from its own view module, appears
   in `REGISTRY.all()`, in `GET /v1/views`, in the OpenAPI union with a
   rendered example and in the generated prompt fragments, with **no shared
   registry, enum or `if/elif` edited** (ADR-K D-7, D-15).
2. **AC-2** `render(portfolio, options)` is pure — no I/O, no repository, no
   clock — and answers the seeded portfolio's default scenario (0.5 BTC,
   FIFO) with two rows: `lot-btc-01` **long**, fully sold, `+$8,925.00`, and
   `lot-btc-02` **short**, partial, `+$580.00`.
3. **AC-3** The short/long split carries **one entry per `LotTerm`, always**,
   built by iterating the enum, in enum order, whether or not the sale touched
   that term — a sale entirely inside one term still renders the other at
   `$0.00` with `0` lots. The two halves sum exactly to `realized`.
4. **AC-4** Every figure the payload carries is a pre-formatted string: money
   as `MoneyDisplay` beside its exact `Decimal`, a gain or loss signed, the
   unit price through `price_display` (four decimals for a sub-cent asset such
   as DOGE), units as a trimmed string.
5. **AC-5** `lot_method` is honoured: the same 0.5 BTC under `LIFO` consumes
   `lot-btc-02` first, under `HIFO` the dearer lot first, and each row's `term`
   follows the lot it came from.
6. **AC-6** `fields` trims `lots` and `remaining`; an unknown section is a 422
   naming it; `by_term`, the totals and the subtitle are never trimmed.
7. **AC-7** An undeclared option, an out-of-range `precision`, a malformed
   `symbol` and a malformed `quantity` are each rejected by the options model
   (422), never best-effort guessed.
8. **AC-8** A scenario the data cannot satisfy fails as a domain error, not as
   a wrong payload: an unheld symbol is `SymbolNotFoundError` (404) and an
   over-sell is `PositionTooSmallError` (422).
9. **AC-9** `fitness` scores **0** for every portfolio, so the no-preference
   selection rule never picks this view: a sale scenario cannot be inferred
   from a portfolio, and guessing one would put figures about a trade nobody
   proposed under a chart that looks authoritative.
10. **AC-10** `surface(payload)` maps onto a single `TaxLotTable` A2UI
    component carrying the totals, the split, the rows and the remainder, and
    the adapter is the only place the component catalog is named.
11. **AC-11** The id `tax_lots.table.v1` is accepted by `ViewQuery`, by
    `RenderIntent` and by the batch entry — proven by a test, because the
    pattern they share rejected it before this spec (OD-2).
12. **AC-12** `make gate` stays green: ruff, basedpyright strict, the 150-line
    budget, `make quality`, pytest at 100 % branch coverage, pip-audit.

## 7. Test plan

Unit tests live in `tests/unit/presentation/test_tax_lots_table.py` (the
projection) and `test_tax_lot_render.py` (the split and the figures), split the
same way the source is and for the same reason.

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `test_registry.py::test_the_process_registry_holds_every_reference_projection`, `tests/unit/api/test_openapi_projections.py` (already generic over the registry) | `test_views_flow.py::test_the_catalog_is_served` |
| AC-2 | `test_tax_lots_table.py::test_render_walks_the_lots_the_sale_consumes`, `::test_render_is_pure_over_the_same_portfolio`, `::test_a_lowercase_ticker_is_normalised_by_the_domain` | — |
| AC-3 | `test_tax_lot_render.py::test_the_term_split_has_one_entry_per_term` (ids `both-terms`, `long-only`), `::test_the_term_split_sums_to_the_realized_total` | — |
| AC-4 | `test_tax_lot_render.py::test_money_is_paired_with_its_exact_decimal`, `::test_a_gain_and_a_loss_are_signed`, `::test_a_sub_cent_price_keeps_four_decimals`, `::test_precision_never_rounds_the_unit_price`, `::test_units_are_trimmed`, `::test_render_honours_the_locale` | — |
| AC-5 | `test_tax_lots_table.py::test_render_honours_the_lot_method` (ids `FIFO`, `LIFO`, `HIFO`) | — |
| AC-6 | `test_tax_lots_table.py::test_render_trims_unselected_sections` (ids `lots-only`, `remaining-only`), `::test_render_rejects_an_unknown_section` | — |
| AC-7 | `test_tax_lots_table.py::test_options_reject_what_they_do_not_declare` (ids `undeclared`, `precision`, `symbol`, `quantity`) | — |
| AC-8 | `test_tax_lots_table.py::test_a_scenario_the_data_cannot_satisfy_raises` (ids `unknown-symbol`, `over-sell`, `zero-quantity`) | — |
| AC-9 | `test_tax_lots_table.py::test_fitness_never_selects_this_view` | — |
| AC-10 | `test_tax_lot_render.py::test_surface_maps_the_payload_onto_the_table` | — |
| AC-11 | `test_tax_lot_render.py::test_the_view_id_is_reachable_by_every_caller` | `test_views_flow.py::test_the_tax_lot_table_is_served_over_http` |
| AC-12 | `make gate` | — |

Mutation checks required (auth / rate limit / error masking): **no** — this
ticket adds no authentication, rate limiting or masking behaviour. The
equivalent here is AC-7 and AC-8: AC-7's four rejections are what prove the
options model can fail at all, and AC-8 is what proves a scenario the data
cannot satisfy fails loudly instead of rendering a plausible wrong table.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | **What does `render()` take?** Every registered projection renders the `Portfolio`. This one renders a `SaleSimulation`, which the portfolio does not contain. | Implementer | **Resolved: `render(portfolio, options)`, unchanged — the scenario travels as declared options and `render` calls the pure domain walk.** The `Projection` Protocol spells `render` as `Callable[[Portfolio, Any], ProjectionDto]`, and ADR-K D-6 words the same thing more loosely as *domain result + options → DTO*. The narrow spelling is not the obstacle it looks like: `simulate_sale` is itself pure — no I/O, no clock, `as_of` arrives on the portfolio — so `(portfolio, {symbol, quantity, lot_method}) → SaleSimulation → DTO` is a pure function of exactly the two arguments the Protocol already passes. The existing projections also *call* domain code (`portfolio.holdings()`, `total_unrealized_pl()`); the only real difference is that this view must **name** the result it wants, and ADR-K D-3 already says how a caller names things: declared, bounded options. Nothing is widened, no shared file is touched, and both callers keep one validation path. **The cost, recorded honestly:** (a) `render` can now raise a *data* error, which no other projection can — §3 lists the three and both callers already handle them; (b) `ProjectionSpec.example` renders at **default** options, so this view must carry a default scenario (0.5 BTC, FIFO) that the seeded portfolio can satisfy, which is a real coupling between a projection and the seed; (c) the `?view=` path cannot set `symbol`/`quantity`/`lot_method`, because `ViewQuery` declares only the shared knobs (spec 0005 OD-1) — over HTTP this view renders its documented default scenario, and the agent and batch paths, whose options are free mappings, drive it fully. **What would genuinely not fit:** a projection over a domain result that cannot be derived from a `Portfolio` plus bounded options — one needing a repository, a second aggregate or a clock. That projection cannot implement this Protocol, and `spec.py` already says so ("a projection that needs a different shape may implement the Protocol itself"). It would need a second `ProjectionSpec`-shaped implementation, not a widened `render`, and the registry would need a render signature it cannot type. We are not there; this view is not the one that takes us there |
| OD-2 | The ticket's id `tax_lots.table.v1` does not match `VIEW_ID_PATTERN`. | Implementer | **Resolved: widen the pattern by one character class.** `^[a-z][a-z0-9]*(\.…` admits `_` in every segment *except the first*, which is an inconsistency rather than a rule — ADR-K D-1 illustrates the same view as `taxlots.table.v1` and that is why nobody hit it. The id in the ticket is the one GGU-41 freezes with the component, so the pattern moves: `[a-z][a-z0-9_]*`. It still rejects a leading `_`, a leading digit and an empty segment. This is the **one shared file** this feature edits; it is not an extension chain and it breaks no existing id, but it is a contract widening and is called out in the PR |
| OD-3 | How does the sale size reach a projection? | Implementer | **Resolved: a pattern-bounded decimal string, parsed with `Decimal`.** Identical to spec 0013 OD-2 and for the identical reason: a JSON number is a `float` before this code sees it, and `Decimal(str(x))` does not repair a value whose precision is already gone. The pattern is spelled a second time here rather than imported, because `app.presentation` may not import `app.agent` (the boundary test) — a **second** occurrence, which the DRY rule allows; a third means it moves into `app.domain.money`, and the PR says so |
| OD-4 | Should the projection accept `amount_usd`, as the tool does? | Implementer | **Resolved: no, units only.** Resolving dollars to units is a division against a price, and it already lives in `SimulateSaleArguments.units(price)` — inside `app.agent`, which this layer may not import. Copying it here would be the second copy of a *financial* rule rather than of a pattern, and the layer that must never hold a business rule is this one (ADR-K D-6). The flow still works: `simulate_sale` resolves a dollar ask and returns `quantityDisplay`, and the model fills `quantity` by **copying that string** — numbers-from-tools, not model arithmetic. Making `amount_usd` renderable means first promoting the resolution into `app.domain`, which is a domain change and a different ticket |
| OD-5 | `precision` applies to every figure. Does it apply to the unit price? | Implementer | **Resolved: no — the price is quoted at its own precision.** `price_display` carries four decimals when cents cannot express the price, because the reader multiplies the price by the quantity beside it and `$0.13 × 12,000` reads $1,560.00 against proceeds of $1,527.60 in the same block (spec 0013 OD-4). Letting `precision=0` round the price would reintroduce exactly that, and the widget has no way to know it happened. `precision` governs the money totals and the row figures, which are results rather than multiplicands |
| OD-6 | `fields` can trim sections. Can it trim the short/long split? | TL | **Resolved: no. `fields` offers `lots` and `remaining` only.** The split *is* the answer Flow B exists to give; a payload that can omit it renders as a plain list of disposals with no tax story, which is the failure this component was drawn to prevent. Two further guards make the split unrenderable-wrongly rather than merely present: it is built by iterating `LotTerm` itself, so there is exactly one entry per term, in enum order, and a term the sale never touched still appears at `$0.00` / `0` lots instead of vanishing; and the figures come from `SaleSimulation.pl_in`/`lots_in`, which re-read the consumed rows every call, so the split cannot disagree with the table beside it. For the same reason there is no `top_n`: truncating the rows would leave a table whose terms no longer add up to the split above it |
| OD-7 | One module per chart (ADR-K D-15) versus the 150-line budget. | Implementer | **Resolved: four new modules, zero shared ones.** D-15's requirement is that adding a chart **edits no shared file**, not that it adds exactly one file — and the budget is a hard gate that is never lowered. The split follows the seams spec 0013 already cut through the same data: what the payload **is** (`tax_lots.py`), what was **asked for** (`tax_lot_scenario.py`), how it is **built** (`tax_lot_render.py`), and what the **projection** is (`views/tax_lots_table.py`) — the same four-way split as `sale_results` / `sale_request` / `sale_rows` / `simulate_sale`. The three non-view modules sit beside `fragments.py` rather than inside `views/`, because `views/` is asserted to contain exactly one `register(...)` per file. The rule text in `.claude/rules/backend/presentation.md` §1 still says "`views/<name>.py` is the **only** file a new chart touches"; on this evidence it means *edits*, and a chart whose payload is a table of rows cannot hold its DTO, its options and its builders in 150 lines. Worth reconciling in the rule |
| OD-8 | Should `simulate_sale` now emit a render intent pointing here? | TL | **Resolved: yes, eventually — not in this PR.** Spec 0013 OD-5 refused to point at a view that did not exist; that reason is gone. But the tool's payload and this projection's options are not the same shape (the tool resolves `amount_usd`, this view does not, OD-4), so wiring them is a decision about the *tool's* contract and belongs to a ticket that can change spec 0013. Shipping the surface first is the order OD-5 asked for: the component arrives, then the tool points at it |
| OD-9 | Does a lot's unit count need a `QuantityDisplay` pair? | Implementer | **Resolved: no, a pre-formatted string is enough.** ADR-K D-5 requires the string and permits the exact `Decimal` beside it *for charting*. Nothing charts a lot's unit count — the table prints it — so the pair would be a new shared primitive (ADR-K D-16) added for a consumer that does not exist. It stays a bounded string here. The day a view plots quantities, `QuantityDisplay` is added to `displays.py` with its tests, and this row adopts it |
| OD-10 | Where does `signed_money` belong — money with an explicit `+`? | Implementer | **Resolved: local to this feature for now.** `app.core.display.signed_money_display` already exists and is shared; what this adds is only the `MoneyDisplay` *pairing* of it, which no other projection needs yet (the waterfall signs by `direction`, not by the string). It lives in `tax_lot_render.py`. A second projection that needs a signed pair promotes it to `displays.py` beside `money()`, and that is a one-line move |

## 9. Rollout & observability

Nothing new to roll out: the projection is served by routes that already exist,
behind the `views.read` / `views.catalog` flags that already gate them, so a
misbehaving table is switched off with the flag rather than a deploy.

No new metric. A render intent naming this view and getting its options wrong
already increments `presentation.render_intent.rejected` with the view as a
tag, which is the signal that would show the prompt fragments teaching the
scenario options badly. Renders are not logged — the projection is pure, so a
payload is reproducible from `(as_of, view, options)` alone, and a sale
scenario in a log line is a trade-shaped statement nobody made.
