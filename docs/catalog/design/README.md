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

**The detail pages for `OrderTicket`, `PayoffChart` and `AllocationSummary`
were not exported.** Those three components are therefore named by their
gallery card and carry no guidance. If those pages arrive, this file and
`DESIGN_CATALOG` are what to update — and the gate will name every rendering
that disagrees.

## What each page declares

A page names its component in up to four places, and they do not always agree.
The **Zone 2 A2UI schema** wins (spec 0023 §3): it is the literal a client
would read off a payload.

| Component | Zone 2 schema | Breadcrumb | Badge | Gallery index card | **Adopted** |
|---|---|---|---|---|---|
| Attribution waterfall | `AttributionWaterfall` | `AttributionWaterfall` | `WaterfallChart` | `WaterfallChart` | **`AttributionWaterfall`** |
| Scenario comparison | `ScenarioComparison` | `ScenarioComparison` | *(none)* | `ComparisonCard` | **`ScenarioComparison`** |
| Tax-lot table | `TaxLotTable` | `TaxLotTable` | `TaxLotTable` | `TaxLotTable` | **`TaxLotTable`** |
| Holdings & allocation | *not exported* | — | — | `AllocationSummary` | **`AllocationSummary`** |
| Order ticket | *not exported* | — | — | `OrderTicket` | **`OrderTicket`** |
| Risk / payoff | *not exported* | — | — | `PayoffChart` | **`PayoffChart`** |

The waterfall's own prompt fragment additionally calls the allocation
component `HoldingsSummary`. A name used for a component on **another**
component's page is never authoritative — that is the third spelling, and it
is why the rule is worded the way it is.

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

## Where the design and this backend disagree

Recorded so the next reader does not re-litigate it.

| The design says | We ship | Why |
|---|---|---|
| every figure is a bare `number` | the ADR-E pair: raw **and** pre-formatted string | ADR-K D-5 permits the raw figure *beside* the string, never instead of it. Conceding would move formatting into the client and break GGU-42. Spec 0023 §5. |
| `ScenarioComparison` has `recommended` and `metrics[].betterWhen` | neither; the card names the spread | Spec 0017 OD-4 decided this card ranks nothing. **Live disagreement — needs the TL.** |
| `TaxLotTable` has `selectedLotIds` | the lots a sale *consumes* | Same information from the other end. A selection round-trip is a new declared option plus a new action, i.e. its own ticket. |
| `compute_attribution()`, `get_holdings()` | rendering the view | `compute_attribution` is not a tool this host registers; the guidance points at the rule instead of a function that would 404. |
| `onSegmentTap(key)` | `drill.attribution.v1` with `driver = <bucket.key>` | The affordance is the same one; ours is a registered, versioned action with an enforced bound (GGU-78). Spec 0023 §6. |

[test]: ../../../backend/tests/unit/presentation/test_component_names.py
