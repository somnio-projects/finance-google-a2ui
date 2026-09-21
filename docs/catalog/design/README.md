# The design catalog, as evidence

Source of truth for [`tests/unit/presentation/test_component_names.py`][test]
and for the guidance in `backend/src/app/presentation/*_guidance.py`.
Reasoning: [spec `backend/0023`](../../../specs/backend/0023-catalog-serves-the-client.md) §3–§4.

Everything else in the generated catalog is read from the projection registry.
**This page is the one exception, and it has to be**: `DESIGN_CATALOG` is the
*counterparty's* half of the contract, and a test that compares the backend
against a copy of the backend proves nothing. So the evidence is transcribed
here — as text that diffs in a pull request, the same rule
[`.claude/rules/diagrams.md`](../../../.claude/rules/diagrams.md) applies to
architecture — rather than cited by a path on someone's laptop.

## Provenance

Four pages were exported from the design catalog and handed over on
**2026-09-21** for GGU-53: `Catalog Index`, `Catalog - Attribution Waterfall`,
`Catalog - Scenario Comparison`, `Catalog - Tax-Lot Table`. They are
JS-bundled HTML (~900 KB each) and are **not** committed: a binary-ish bundle
is the thing that drifts silently and cannot be reviewed. What they *declare*
is committed, below.

**The remaining three detail pages — `Catalog_OrderTicket`,
`Catalog_RiskPayoffChart`, `Catalog_HoldingsSummary` — were exported later the
same day**, and GGU-102, GGU-103 and GGU-101 read them. Two of the three names
this file had adopted from a gallery card were wrong the moment their own
Zone 2 block existed; spec `backend/0024` §2 renamed them, which is a breaking
change for the client and is why open PRs #73 and #75 must follow.

**What is still not transcribed, and why it matters.** Those three pages'
Zone 3 fragments are *quoted in the tickets, not held in this repository* —
the exported HTML was read by the agents that raised GGU-101..GGU-104 and is
not committed, so nobody can transcribe the fragments verbatim from here. Two
components therefore still carry **no guidance**, which the contract prints as
"no design page for this component yet". That sentence is now *imprecise
rather than false*: the pages exist, their text has not reached us in a form
we may copy. §"Zone 3 — the audit" below records what is known about them.

## What each page declares

A page names its component in up to four places, and they do not always agree.
The **Zone 2 A2UI schema** wins (spec 0023 §3): it is the literal a client
would read off a payload.

| Component | Zone 2 schema | Breadcrumb | Badge | Gallery index card | **Adopted** |
|---|---|---|---|---|---|
| Attribution waterfall | `AttributionWaterfall` | `AttributionWaterfall` | `WaterfallChart` | `WaterfallChart` | **`AttributionWaterfall`** |
| Scenario comparison | `ScenarioComparison` | `ScenarioComparison` | *(none)* | `ComparisonCard` | **`ScenarioComparison`** |
| Tax-lot table | `TaxLotTable` | `TaxLotTable` | `TaxLotTable` | `TaxLotTable` | **`TaxLotTable`** |
| Holdings & allocation | `HoldingsSummary` | `HoldingsSummary` | `HoldingsSummary` | `AllocationSummary` | **`HoldingsSummary`** |
| Order ticket | `OrderTicket` | `OrderTicket` | `OrderTicket` | `OrderTicket` | **`OrderTicket`** |
| Risk / payoff | `RiskPayoffChart` | `RiskPayoffChart` | `RiskPayoffChart` | `PayoffChart` | **`RiskPayoffChart`** |

The waterfall's own prompt fragment additionally calls the allocation
component `HoldingsSummary`. A name used for a component on **another**
component's page is never authoritative — that is the third spelling, and it
is why the rule is worded the way it is. It happens to be the name its *own*
Zone 2 block now gives, and that coincidence changes nothing about the rule:
what renamed the component is its own page, which arrived later.

**The fallback is not a tie-break.** The last three rows read *not exported*
until 2026-09-21 and their gallery card won by default. When the pages
arrived, two of those defaults lost. A row filled in from a gallery card is
therefore **provisional**, and the day a detail page lands is the day to come
back to this table — not the day someone notices the client is registering a
widget under a name design never wrote.

## Zone 3 — the fragment injected into the system prompt

Verbatim from the pages, for the three that have one. Where our wording
departs from this, the reason is in the module that carries it and in spec
0023 §4.

> **AttributionWaterfall** — Use `AttributionWaterfall` when the user asks WHY
> a value changed and the answer decomposes into signed contributions that sum
> to a net delta (e.g., what drove portfolio return, P/L by position). Set
> `start` and `end` to the endpoints, list each driver in `contributions` with
> a signed value, and order them largest-magnitude first. Do not use it for a
> simple current breakdown — use `HoldingsSummary` for that. Never compute the
> numbers yourself; call `compute_attribution()` and pass its output.
>
> *Do* — decompose a delta into signed drivers.
> *Don't* — show a static composition (use Holdings).

> **ScenarioComparison** — Use `ScenarioComparison` when the user faces a
> choice between 2–4 strategies and the decision hinges on comparing the same
> metrics across them (lot-selection, buy-now-vs-later, contribution sizing).
> Define `metrics` once with `betterWhen` so the client can emphasize the
> winning cell; do not pre-bold values in text. Mark at most one scenario
> `recommended`, and only when a tool result justifies it. Never fabricate the
> comparison — each scenario's values come from a tool call.
>
> *Do* — compare identical metrics across options.
> *Don't* — use for a single option (no comparison).

> **TaxLotTable** — Use `TaxLotTable` when the user asks about selling a
> position and tax consequences depend on WHICH lots are sold. Populate `lots`
> from `get_holdings()`; mark the lots the chosen strategy consumes in
> `selectedLotIds`; fill `realizedSummary` from `simulate_sale()`. Always split
> gains into long- vs short-term. Never estimate tax rates in prose — surface
> figures the tools returned.
>
> *Do* — highlight ST vs LT by holding period.
> *Don't* — merge lots into one row (loses tax detail).

## Zone 3 — the audit

Spec `backend/0024` §5. A Zone 3 fragment is **prompt text**: it is generated
into the catalog the model reads, so a sentence in it that tells a reader to
work a figure out is the numbers-from-tools invariant broken in the one place
designed to teach the model the rules. **A fragment is transcribed only after
it has been read against that invariant**, and a fragment we decline to ship
is recorded here rather than silently dropped.

All six, against the question *does any sentence ask anybody to compute,
recompute, derive or estimate a figure?*

| Component | Fragment we ship | Verdict |
|---|---|---|
| `AttributionWaterfall` | `waterfall_guidance.py` | **Clean.** It states the rule explicitly: *"Never write the figures yourself: render this view and copy the `display` strings it returns."* Design's `compute_attribution()` was already replaced, for a different reason (no such tool), and the replacement happens to be the stronger sentence. |
| `TaxLotTable` | `taxlots_guidance.py` | **Clean.** *"Never estimate a tax rate in prose"* is design's own wording and is the invariant in a designer's voice. |
| `ScenarioComparison` | `scenario_guidance.py` | **Clean, but only because we rewrote it.** Design's page says to define `metrics` with `betterWhen` *"so the client can emphasize the winning cell"* — a comparison performed in the client, which is N-2 as well as the ranking OD-4 refuses. Ours teaches the rule the payload enforces. See the disagreement table. |
| `HoldingsSummary` | *none* | **Not transcribed.** The page exists (GGU-101 gap 6); its text is not in this repository. Nothing known against it. |
| `RiskPayoffChart` | *none* | **Not transcribed.** The page exists (GGU-103 gap 9). Its Zone 1 draws `position + protective puts`, which spec 0024 §3 rules out, so any sentence of its guidance that describes an options payoff must be dropped rather than copied. |
| `OrderTicket` | *none* | **Not transcribed, and it must not be as written.** The page describes the component as one that *"recomputes weights, cash and shares live as parameters change"* (GGU-102). Shipped as prompt text that instructs the reader to recompute figures, which is precisely what this product's central invariant forbids and what `order.ticket.v1`'s `effect: "recalculate"` deliberately does **not** mean: the *backend* re-renders, the client sends the option back. |

### The one-line change for design

> **`OrderTicket` Zone 3** — replace *"recomputes weights, cash and shares live
> as parameters change"* with *"re-renders with the figures the backend
> returns when a parameter changes"*.

Same behaviour on screen; the difference is who does the arithmetic, and the
fragment is the one place that difference is taught. With that wording the
fragment can be transcribed as-is.

## Where the design and this backend disagree

Recorded so the next reader does not re-litigate it.

| The design says | We ship | Why |
|---|---|---|
| every figure is a bare `number` | the ADR-E pair: raw **and** pre-formatted string | ADR-K D-5 permits the raw figure *beside* the string, never instead of it. Conceding would move formatting into the client and break GGU-42. Spec 0023 §5. |
| `ScenarioComparison` has `recommended` and `metrics[].betterWhen` | neither; the card names the spread | **Settled 2026-09-21 — the TL ruled for spec 0017 OD-4, and it stands.** Picking a lot-selection method for someone is tax advice this showcase is not licensed to give, and a bigger realised gain is not reliably the good outcome. `betterWhen` does not escape that: it ships the ranking *rule* and has the client apply it, which is `recommended` with one extra hop and puts the client back to comparing numbers (N-2). A per-row `best` marker is not a middle ground — it is the field OD-4 names first. `spread.highest` / `spread.lowest` name the extremes without ranking them and are as far as this card goes. Reopening it reopens OD-4 and is its own ticket, not a field. Spec 0024 §6. |
| `TaxLotTable` has `selectedLotIds` | the lots a sale *consumes* | Same information from the other end. A selection round-trip is a new declared option plus a new action, i.e. its own ticket. |
| `OrderTicket` is multi-leg, with an impact panel and constraints | one leg, `symbol` · `side` · `size` · `size_in` | **Settled 2026-09-21.** `order.ticket.v1` stays single-leg for the demo. Multi-leg is not a backwards-compatible addition to a single-leg payload — it is `order.ticket.v2`, raised as GGU-108 and post-demo. Spec 0024 §3. |
| `RiskPayoffChart` draws `position + protective puts` | a linear spot payoff | **Settled 2026-09-21.** The projection's own required disclosure says there is no strike, no expiry and no implied volatility behind the line, and this portfolio holds no options position. Drawing a kinked curve would assert one thing while the disclosure denied it on the same screen. An options payoff, if it is ever wanted, is a separate versioned view with its own options and its own disclosure. Spec 0024 §3. |
| three pages have no slot for `disclosure` / `notes[]` | both are required fields | N-9 makes them mandatory and verbatim, so the slot is design's to add: `OrderTicket`, `RiskPayoffChart` and `ScenarioComparison`. Raised as GGU-109. The backend serves all three unambiguously (spec 0024 §6); the Flutter builds in PRs #70, #73 and #74 already place them, so what is missing is the design slot, not the string. |
| `compute_attribution()`, `get_holdings()` | rendering the view | `compute_attribution` is not a tool this host registers; the guidance points at the rule instead of a function that would 404. |
| `onSegmentTap(key)` | `drill.attribution.v1` with `driver = <bucket.key>` | The affordance is the same one; ours is a registered, versioned action with an enforced bound (GGU-78). Spec 0023 §6. |

[test]: ../../../backend/tests/unit/presentation/test_component_names.py
