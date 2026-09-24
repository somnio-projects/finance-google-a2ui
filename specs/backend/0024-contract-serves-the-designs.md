# 0024 — The contract serves what the designs draw

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-99](https://somniosoftware.atlassian.net/browse/GGU-99) · **Closes:** [GGU-101](https://somniosoftware.atlassian.net/browse/GGU-101) (naming half), [GGU-103](https://somniosoftware.atlassian.net/browse/GGU-103) (naming + markers), [GGU-104](https://somniosoftware.atlassian.net/browse/GGU-104) (the ranking ruling) · **Raises:** [GGU-108](https://somniosoftware.atlassian.net/browse/GGU-108), [GGU-109](https://somniosoftware.atlassian.net/browse/GGU-109)
- **Also:** 0015 (tax-lot table), 0016 (payoff curve), 0017 (scenario comparison), 0018 (order ticket), 0023 (catalog serves the client), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

GGU-53 (spec 0023) compared four exported design pages against what this
backend serves and fixed what it found. The remaining two pages were exported
afterwards, and GGU-99..GGU-104 then ran the comparison for **all six**
components. The result was thirty-odd gaps and, more usefully, a handful of
questions that only a decision could close: is the backend wrong, or is the
design?

The TL ruled on seven of them on **2026-09-21**. This spec is where those
rulings live, because six weeks from now the interesting artefact is not the
diff — it is *why the payload does not have a field somebody can see in a
design*. Everything below is either a ruling or its consequence.

What this spec is **not**: it is not the whole of GGU-100..GGU-104. Those
tickets list gaps that were not ruled on (the waterfall's net-delta pill, the
allocation gain block, `groupBy`, the day-change column, axis metadata, the
comparison state). Those stay open under their own tickets.

## 2. Scope

**In**

- The two component renames the design's Zone 2 now requires, and the
  regenerated artefacts (§2).
- The arity ruling for `order.ticket.v1` and the payoff-shape ruling for
  `payoff.curve.v1` (§3).
- `markers` on `payoff.curve.v1` — the break-even made placeable without a
  label match (§4).
- The Zone 3 fragment audit against the numbers-from-tools invariant (§5).
- Two compliance rulings recorded where the next reader looks: no ranking on
  the comparison card, and `disclosure` / `notes[]` unambiguous on the wire
  (§6).
- Two missing `*_display` fields on `taxlots.table.v1`, and the withdrawal of
  three field groups nothing binds (§7).

**Out**

- Multi-leg order tickets → `order.ticket.v2`, **GGU-108**, post-demo.
- Design slots for `disclosure` / `notes[]` and the client work that follows
  → **GGU-109**.
- Every declared action (`onSegmentTap`, `onSliceTap`, `onScenarioSelect`,
  `onSubmit`, `onPointHover`) → **GGU-78**, unchanged. The capability flag
  still empties `DECLARED_ACTIONS`; that is recorded, not re-solved.
- The client-side follow-ups in PRs #70, #71, #73, #74 and #75.

## 3. API contract

No route changes. Three payloads change shape, so the `oneOf` members and both
generated artefacts move with them.

| View | Field | Change |
|---|---|---|
| `payoff.curve.v1` | `markers` | **added**, required, `{break_even, current}`, each `{label, at{amount, display}}` |
| `taxlots.table.v1` | `lots[].acquired_on_display` | **added**, required, `string ≤32` |
| `taxlots.table.v1` | `lots[].units` | **changed**: was a formatted `string`, now the exact `Decimal` |
| `taxlots.table.v1` | `lots[].units_display` | **added**, required, `string ≤32` |
| `taxlots.table.v1` | `price` | **removed** |
| `taxlots.table.v1` | `remaining[]` | **removed**, and `remaining` is no longer an accepted `fields` section (422) |

A2UI surface props, which are a separate rendering of the same facts:

| Component | Prop | Change |
|---|---|---|
| `RiskPayoffChart` | `markers` | now the keyed block; the labelled callouts moved to a new `annotations` prop |
| `TaxLotTable` | `totals` / `remaining` | `Price` gone from `totals`; `remaining` gone |
| `ScenarioComparison` | `notes` | now the whole `Annotation` (`label` **and** `text`), not `text` alone |

**Breaking, and named as such.** The two renames below and the `markers`
reshaping are what a client registers and binds against. Open PRs **#73**
(`RiskPayoffChart`) and **#75** (`HoldingsSummary`) must follow; PR **#71**
binds no removed field and needs only the two new ones.

## 4. Data model & migration

None. No table, column or Alembic revision is touched — every change is in the
presentation layer and in the curated demo data's *rendering*, never its
storage.

## 5. Security notes

No change to authentication, authorization, scopes, audit events or rate
limits. Two notes belong here anyway, because both are compliance surfaces:

- **`disclosure` and `notes[]` are compliance text** and N-9 requires them
  verbatim. §6 makes the A2UI rendering of `notes[]` carry both halves; before
  this spec a genui client received the sentences without their captions.
- **The payoff disclosure is load-bearing**, not boilerplate: it is the only
  thing distinguishing a linear spot payoff from an options payoff, which is
  exactly why §3's ruling refuses to draw the latter.

---

## §2 — Component names: the design's Zone 2 wins

**Ruling.** Spec 0023 §3 already says a component is named by its own Zone 2
A2UI schema block. The repository follows its own rule rather than bending it
because following it is now expensive.

| View id | Was | Now |
|---|---|---|
| `payoff.curve.v1` | `PayoffChart` | **`RiskPayoffChart`** |
| `holdings.allocation.v1` | `AllocationSummary` | **`HoldingsSummary`** |
| `order.ticket.v1` | `OrderTicket` | `OrderTicket` — its page agrees |

Both old names came from a **gallery index card**, adopted under 0023 §3's
fallback for a component whose detail page had not been exported. The pages
have since been exported. The fallback is a fallback, not a tie-break: a row
filled in from a gallery card is provisional, and the day the detail page
lands is the day to revisit it. `docs/catalog/design/README.md` now says so in
the table itself, so the next person does not have to infer it.

Five places moved together, and the gate is what makes that true rather than
hoped: the A2UI adapter, `DESIGN_CATALOG` in `test_component_names.py`, the
JSON snapshot, the Markdown contract and `GET /v1/views`.

## §3 — Two shapes that stay as they are

**`order.ticket.v1` stays single-leg.** The contract is symbol-agnostic — it
takes a `symbol` option — so "it is a crypto ticket" was a property of the
sample, never of the payload. Multi-leg is **not** a backwards-compatible
addition: a client binding `symbol` and `quantity` at the root cannot be
handed a payload where they live inside `legs[0]`, and a `legs[]` that always
has exactly one entry is an illegal state made representable. It is therefore
`order.ticket.v2` — **GGU-108**, post-demo, not built here.

> **The sample symbol was *not* changed, and this is the one instruction in
> the ruling that could not be carried out.** It asked for an equity
> "consistent with the rest of the portfolio (the tax-lot and attribution data
> are equities; pick one that already appears there)". **There are no equities
> in this backend.** `domain/market.py` is eight crypto assets; `seed_data.py`
> is BTC, ETH, SOL, LINK and DOGE; the tax-lot table's own default is `BTC`
> because BTC's two lots straddle the one-year boundary; the attribution story
> is ETH and LINK against BTC and SOL. The only equity ticker anywhere is
> `NVDA` inside two prose examples, which no projection can render. Adding one
> would make this view's sample the single asset the demo portfolio does not
> hold — *less* consistent, not more. `symbol` stays `BTC`; the evidence is on
> GGU-102 and the question is carried into GGU-108, where the same gap blocks
> the design's `sectorWeightBefore` / `sectorWeightAfter` rows.

**`payoff.curve.v1` stays a linear spot payoff.** Its summary says so and its
required `disclosure` exists to say so: *"There is no strike, no expiry, no
implied volatility and no time decay behind this line."* The design's default
state is labelled `position + protective puts`, which needs a strike, a
premium and an expiry — three inputs spec 0014 OD-8 and spec 0016 refused on
purpose, and an options position this portfolio does not hold. Drawing the
kinked curve would put the chart and its own disclosure in contradiction on
one screen, which is the failure the disclosure was written to prevent. An
options payoff, if it is ever wanted, is a **separate versioned view** with its
own options and its own disclosure — never a widening of this one.

## §4 — The break-even becomes placeable

**The defect.** `totals[]` is `{label, amount}` and `annotations[]` is
`{label, text}`. Neither carries a key, so a widget could locate the
break-even only by matching the string `"Break-even price"`. That is
prohibition N-5 (the client interpreting a server string) and it is wrong the
first time `locale` renders that label in Spanish — the rule silently
disappears from the chart and nothing goes red. PR #73 declined to do it and
recorded the ask; `frontend/0005` OD-1 states it exactly.

**The shape chosen: the design's own `markers: { breakEven, current }`.** The
payload gains a `markers` block with two **named fields**, each a
`{label, at{amount, display}}`. The address of a marker is now a path a
component's author writes as a literal, so relabelling moves nothing and a
*missing* marker is a `PayloadContractException` naming the path rather than a
line that quietly fails to draw.

**The alternative, and why not.** A discriminator on `totals[]` entries would
also work, but `Total` is a **shared fragment**: a required `key` on it reaches
into every other view's payload to solve one view's problem (ADR-K D-15), and
an optional one leaves the string match in place as a fallback — which is the
thing being abolished. `PriceMarker` / `PayoffMarkers` therefore live in
`presentation/payoff_markers.py`, beside the view, and are promoted into
`fragments.py` only if a second view needs them (D-16).

Two consequences worth stating:

- **`markers` is outside `SECTIONS`**, so no `fields` value can trim it. A
  client that can be served a payload without markers needs a fallback, and
  the only fallback available is the label match.
- **`current` is the reference price at `as_of`**, which for a proposed order
  is also the price it would be entered at — which is why `totals[]` calls the
  same figure *Entry price*. The marker is named for what the reader is
  looking at; the docstring says so rather than leaving two names for one
  number unexplained.

The A2UI adapter's `markers` prop used to carry the four labelled callouts.
They are now `annotations`, which is what they are. `payoff.curve.v1`'s DTO
moved to `presentation/payoff_payload.py` for the 150-line budget, the same
seam `order_payload.py` already cut.

## §5 — The Zone 3 fragments, audited

A Zone 3 fragment is **prompt text**: `prompt.py` generates it into the catalog
the model reads. A sentence in it that tells a reader to work a figure out
breaks the numbers-from-tools invariant in the one place built to teach the
model the rules.

**The rule this spec adds:** a fragment is transcribed only after it has been
read against that invariant, and a fragment we decline to ship is recorded
rather than silently dropped. The audit of all six is a table in
[`docs/catalog/design/README.md`](../../docs/catalog/design/README.md).

Result: **the three fragments this backend ships are clean.** The waterfall's
states the rule outright; the tax-lot table's is design's own *"never estimate
a tax rate in prose"*; the comparison card's is clean **only because 0023 §4
rewrote it** away from `betterWhen`.

The problem is on design's side, in a page we do **not** ship a fragment for:

> **`OrderTicket` Zone 3** — replace *"recomputes weights, cash and shares live
> as parameters change"* with *"re-renders with the figures the backend returns
> when a parameter changes"*.

Same behaviour on screen. The difference is who does the arithmetic, and it is
precisely what `effect: "recalculate"` does **not** mean: the backend
re-renders, the client sends the option back (spec 0018 OD-1). With that
wording the fragment can be transcribed as-is.

**An honest limit.** The three newly exported pages' Zone 3 text is quoted in
GGU-101..GGU-103, not committed here, so it cannot be transcribed verbatim
from this repository. `holdings.allocation.v1` and `payoff.curve.v1` therefore
still carry **no guidance**, and the contract still prints "no design page for
this component yet". That sentence is now imprecise rather than false — the
pages exist; their text has not reached us in a form we may copy. Inventing
two plausible sentences here would be indistinguishable from two a designer
approved, which is the rule `presentation/guidance.py` already states.

## §6 — Two compliance rulings

**`recommended` and `betterWhen` stay out of `scenario.comparison.v1`.** Spec
0017 OD-4 stands: this card ranks nothing, keeps the caller's column order,
never sorts by outcome, and names the spread between the extremes without
calling either better. `betterWhen` does not escape that ruling — it ships the
comparison rule and has the *client* apply it to pick a winning cell, which is
`recommended` with one extra hop and puts the client back to comparing
numbers (N-2). A per-row `best` marker is not a safe middle ground; it is the
field OD-4 names first.

Nothing is built for this. What changed is **where it is written down**: the
"Where the design and this backend disagree" table in
`docs/catalog/design/README.md` carried this row marked *"Live disagreement —
needs the TL"*, and a decision that lives only in a Jira comment does not
exist (`.claude/rules/backend/sdd.md`). It now carries the ruling and its
reasoning.

**`disclosure` and `notes[]` reach the screen unambiguously.** Both are
required and both render verbatim under N-9. Backend side:

- `payoff.curve.v1` and `order.ticket.v1` already carried `disclosure` in the
  payload and in the surface props. Unchanged.
- `scenario.comparison.v1`'s A2UI adapter **flattened each note to
  `note.text`**, dropping the `label`. *Before tax* and *Not advice* reached a
  genui client without their captions, while the DTO path carried both. Fixed:
  the adapter passes the whole `Annotation`, so the two paths hand a widget the
  same thing.

Three design pages still have no slot for these strings — `OrderTicket`,
`RiskPayoffChart`, `ScenarioComparison`. That is **GGU-109**. Worth recording
so nobody redoes it: the Flutter builds in PRs #74, #73 and #70 already place
all three *without* a design slot, so the remaining work is the slot, not the
string.

## §7 — Fields nothing binds come out, and two that were missing go in

**Out**, checked against all five open client PRs before deleting anything:

| Field | Bound by | Verdict |
|---|---|---|
| `price` (the unit-price `Total`) | nothing | **removed** |
| `remaining[]` | nothing | **removed**, and `remaining` is no longer a `fields` section |
| `cost_basis` / `proceeds` | **`.label` bound by PR #71** as the captions over two columns | **kept** |

The third row is the one to read. The ruling named "the `cost_basis`/`proceeds`
totals" among the candidates for deletion, and the *amounts* are indeed
undrawn — but `taxlots_table_component.dart` binds `cost_basis.label` and
`proceeds.label`, deliberately, because a Dart constant would not follow the
`locale` option. Label and amount travel as one `Total`, so the pair stays.
Splitting a `Total` to serve a label alone would invent a primitive for no
design reason.

Removing `price` also removed `taxlot_render.price_total`. The unit-price
precision rule it enforced (OD-5: `$0.13 × 12,000` misses the proceeds beside
it by $32.40) is **not lost** — the `simulate_sale` tool still quotes through
`price_display`, and `test_sale_rows.py` is where that property is asserted
now. `SaleSimulation.remaining_*` is likewise still used by that tool, so
nothing in the domain went dead.

**In** — the two unambiguous defects GGU-99 lists, neither of them a decision:

- **`lots[].acquired_on_display`.** `acquired_on` shipped as a bare ISO date
  and the client drew it, because re-spelling a date in Flutter is formatting
  (N-4, and `intl` is absent from `lib/` by a layering test). So `2025-01-13`
  was rendering on a card whose every other value is pre-formatted — an ADR-E
  violation visible on screen. A new `app/core/dates.py` is the single
  `date` → string boundary, reading the same locale set as `display.py`.
  **Digits, not month names**: a `Mar 12, 2021` needs a twelve-word vocabulary
  per locale, and an English `Mar` inside a `de-DE` payload would be a second
  defect rather than a nicer one. The *order and separator* are what actually
  mislead a reader (`01/13/2025` vs `13.01.2025`), and those are per-locale.
  If design wants month names, that is a vocabulary to supply, not a format
  string to change.
- **`lots[].units_display`**, with `units` becoming the exact `Decimal`. The
  Shares column was dropped because the payload's only per-lot quantity was a
  string the contract classified as ordinary text, indistinguishable from a
  raw figure — and N-4 names `units` explicitly as geometry. The pair makes
  the printable half unambiguous.

## 6. Acceptance criteria

1. **AC-1** — `payoff.curve.v1` emits `RiskPayoffChart` and
   `holdings.allocation.v1` emits `HoldingsSummary`, and the adapter, the JSON
   snapshot, the Markdown contract and `GET /v1/views` all agree.
2. **AC-2** — `order.ticket.v1` is single-leg and unchanged; multi-leg exists
   only as GGU-108.
3. **AC-3** — `payoff.curve.v1` still renders a linear spot payoff and still
   carries its disclosure.
4. **AC-4** — The break-even is reachable by a field path, cannot be trimmed by
   `fields`, and does not move when the label changes.
5. **AC-5** — All six Zone 3 fragments are audited, the audit is recorded, and
   no fragment this backend ships instructs anybody to compute a figure.
6. **AC-6** — The OD-4 ruling and the N-9 ruling are recorded in
   `docs/catalog/design/README.md`; `scenario.comparison.v1`'s surface carries
   each note's label and text.
7. **AC-7** — `taxlots.table.v1` serves `acquired_on_display` and
   `units_display`; `price` and `remaining[]` are gone; `cost_basis` and
   `proceeds` remain because their labels are bound.
8. **AC-8** — `cd backend && make catalog` rerun, both artefacts committed;
   `cd backend && make gate` green.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `test_component_names.py` (four renderings vs `DESIGN_CATALOG`, plus its own mutation check), `test_payoff_curve.py`, `test_holdings_allocation.py`, `test_catalog_snapshot.py`, `test_render_intent_service.py`, `test_view_service.py` |
| AC-2, AC-3 | unchanged suites for `order.ticket.v1` and `payoff.curve.v1` — the evidence is that nothing in them moved |
| AC-4 | `test_payoff_markers.py` — reached by field name · exact coordinate beside the string · **relabelled by `locale`, does not move** · no `fields` value trims it |
| AC-5 | not machine-checkable; the audit table is the artefact, and `guidance.py` already fails closed by shipping `None` |
| AC-6 | `test_scenario_comparison_contract.py` asserts the surface's notes carry `label` and `text` |
| AC-7 | `test_taxlot_render.py` (the date pair, the units pair, the surface without `Price` or `remaining`), `test_taxlots_table.py` (`remaining` now rejected as an unknown section, beside one that never existed) |
| AC-8 | `make gate` |

**Test decision.** The renames and the marker shape were **mutation-checked**
rather than assumed — a rename no test notices is a rename that silently
breaks client registration, which is the exact defect GGU-53 was written to
catch and which reappeared anyway. The outputs are in the pull request.

## 8. Open decisions

| # | Question | Owner | Default if unanswered |
|---|---|---|---|
| **OD-1** | Does the showcase acquire an **equity slice** (market reference + seed + sectors), or does design restate its examples in the assets the portfolio holds? Blocks GGU-108's impact panel and was the premise of an instruction that could not be executed (§3). | TL | Stay crypto-only; design restates. |
| **OD-2** | Does design want **month names** on the acquisition date? That is a per-locale vocabulary to supply, not a format change (§7). | Design | Digits, in the locale's own order and separator. |
| **OD-3** | The three Zone 3 fragments this repository cannot transcribe — are the pages exported into the repo, or is the text handed over another way? Until then two components ship no guidance (§5). | Design / TL | No guidance rather than invented guidance. |
| **OD-4** | `payoff.curve.v1` still serves `Low`, `High` and `Notional`, which nothing draws (GGU-103 gap 8). §7's rule says a field nothing binds comes out; they were left because GGU-103's own AC pairs them with decisions not ruled on here. | TL | Drop them with the rest of GGU-103. |
