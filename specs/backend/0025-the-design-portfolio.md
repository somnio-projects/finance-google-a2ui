# 0025 — The design portfolio

- **Area:** backend
- **Status:** In progress
- **Ticket:** _unassigned — see §6_
- **Also:** 0003 (portfolio domain), 0024 (contract serves the designs), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

The design is a **US equities portfolio**. This backend held **eight crypto
assets**. Spec 0024's own log recorded it: *"There are no equities in this
backend, and one instruction in the ruling assumed there were."*

That is the blocking prerequisite for every remaining design gap. No component
can be made to match by styling, because the numbers on screen come from here
and were different numbers — and the client cannot invent them, since the
numbers-from-tools invariant is the product, not a convention.

## 2. What the design says, measured

Read from `.design-refs/`, not transcribed. **The position figures are
internally consistent** — every implied price, cost and percentage reconciles
to the cent:

| Symbol | Shares | Avg cost | Implied price | Market value | Unrealized |
|---|---|---|---|---|---|
| NVDA | 90 | $760.00 | $1,204.66 | $108,419.40 | +$40,019.40 (+58.5 %) |
| AAPL | 300 | $155.40 | $233.18 | $69,954.00 | +$23,334.00 (+50.1 %) |
| MSFT | 110 | $305.20 | $423.00 | $46,530.00 | +$12,958.00 (+38.6 %) |
| VOO | 85 | $402.10 | $528.00 | $44,880.00 | +$10,701.50 (+31.3 %) |
| BND | 620 | $74.10 | $71.40 | $44,268.00 | −$1,674.00 (−3.6 %) |
| PYPL | 250 | $88.60 | $65.30 | $16,325.00 | −$5,825.00 (−26.3 %) |
| USD | — | — | — | $38,633.22 | — |

### 2.1 The visible list does not sum to the stated total

| Quantity | Value |
|---|---|
| Visible positions + cash | **$369,009.62** |
| Asset classes (299,407 · 86,925 · 38,633 · 57,950) | **$482,915.00** |
| Stated total | **$482,915.20** |
| **Unaccounted** | **$113,905.38** |

Not an inconsistency: `Holdings.dc.html` describes a *scrollable* list cut at
the fold, and NVDA's weight confirms the denominator (108,419.40 / 482,915.20 =
**22.45 %**, drawn as 22.5 %). *Alternatives* has no visible row at all.

**OD-1 — the unseen positions are ours to choose, and that is recorded.** The
seed closes $113,905.38 across three classes with positions design never drew.
The class totals and the grand total are the constraint; the invented rows
exist only to satisfy it, and they sort after the seven real ones.

## 3. Rulings

- **OD-2 — the crypto reference is replaced, not extended.** Two asset
  universes in one portfolio make every allocation figure meaningless.
- **OD-3 — `MarketAsset` gains `asset_class` and `sector`**, both closed
  vocabularies. A grouping the backend cannot express is one the client would
  have to invent.
- **OD-4 — `MarketAsset` gains `previous_close`.** The day change is drawn on
  every legend row and every position row. It is a second *price*, declared as
  a string and parsed to `Decimal` like every other (ADR-E D-5).
- **OD-5 — price history is a domain concern**, seeded rather than generated at
  request time, so two reads of the same range agree.
- **OD-6 — cash is a holding, not a special case.** The design lists `USD ·
  Cash & sweep` as a row with a market value and a 0.0 % day change.

### OD-7 — the by-sector percentages are gallery data, not a portfolio claim

`Catalog_HoldingsSummary.dc.html` draws the component twice. The two variants
are **not symmetric**, and the asymmetry is the ruling:

| Variant | Shows |
|---|---|
| `DEFAULT · BY ASSET CLASS` | total **$482,915.20**, all-time gain, 4 classes **with dollar amounts** |
| `BY SECTOR · GROUPBY: SECTOR` | `6 / SECTORS`, percentages and day arrows — **no amounts, no total** |

Taken as one portfolio the two contradict each other, and irreducibly:

```
visible Technology positions (NVDA+AAPL+MSFT) = $224,903.40
  as % of the stated portfolio                = 46.6%   (the donut says 34%)
denominator required for 34%                  = $661,480   (portfolio is $482,915.20)
```

No denominator yields 34 %. Truncation cannot explain it either — the list
being partial only *adds* to Technology. And the three tech names are the
design's own, drawn on `Holdings.dc.html` with prices that reconcile, so they
cannot be reduced.

**Ruling: the by-sector variant is the component rendered with different sample
data to demonstrate `groupBy`, not a second statement about this portfolio.**
That is what the missing total and missing amounts say. So:

- the **component** matches the design exactly — centre count (`N / SECTORS`),
  percentage, day-change arrow, six rows, same order and typography;
- the **numbers** are derived from the portfolio, as every number here is.

This is design-first, not a compromise with it: what a catalog page specifies
is a component, and the component is reproduced. Serving 34 % would require the
backend to publish a figure its own holdings contradict, which is the one thing
this project is built not to do. Raised with design as a question about the
gallery sample, not as a defect in the component.

### OD-8 — the day-change hero is inconsistent too, and is out of scope here

The class-level day changes imply **+$3,633 (+0.76 %)** for the whole
portfolio; `Home.dc.html`'s hero says **+$3,240.18 (+0.68 %)**. The hero
belongs to the shell, which does not exist yet, so nothing is decided now. The
seed honours the **class-level** figures, because those are the ones a catalog
component draws.

### OD-9 — NVDA and AAPL each hold two lots at two costs

The design prints one average cost per position — NVDA `$760.00`, AAPL
`$155.40` — and Flow B needs the lot methods to *disagree*: a sale that yields
the same figure under FIFO, LIFO and HIFO leaves `scenario.comparison.v1` with
a `$0.00` spread and nothing to compare, which is what the first equities seed
produced. So the second NVDA lot (30 shares, the short-term one) costs `$960`
and the second AAPL lot (100 shares) costs `$95.40`. The `$6,000` one costs
more is exactly what the other costs less, so every portfolio-level figure the
design states — market value, all-time gain, the class totals — is unchanged;
only the two per-position average costs move (`$826.67` and `$135.40`), and
their unrealised split with them (`+$34,019.40` / `+$29,334.00`, same net).
Selling 30 NVDA now shows FIFO `+$13,339.80` against LIFO/HIFO `+$7,339.80`,
a `$6,000.00` spread with both ends named.

## 4. What the seed produces

Verified against the design, not against itself:

| | served | design | |
|---|---|---|---|
| Equities | $299,407.00 · +1.20 % | $299,407 · +1.2 % | ✅ |
| Bonds | $86,925.00 · −0.30 % | $86,925 · −0.3 % | ✅ |
| Cash | $38,633.22 · 0.00 % | $38,633 · 0.0 % | ✅ |
| Alternatives | $57,949.98 · +0.62 % | $57,950 · +0.6 % | ✅ |
| **Total** | **$482,915.20** | **$482,915.20** | ✅ |
| All-time gain | +$61,204.05 (14.51 %) | +$61,204 (+14.5 %) | ✅ |

## 5. Test decision

The seeded totals are asserted **as literals**, the way
`test_component_names.py` holds design's names as a literal. A derivation check
reading its expectation from the same seed proves only that arithmetic is
arithmetic; the point is that the seed agrees with a page a designer drew.

`test_seed.py`'s existing invariant — `amount == quantity × price` — caught a
real defect in the first draft of this seed, where a fractional VNQ quantity
made the product inexact. The position was re-chosen (93 × $90.86) so the
product is exact; **the constraint found it, not a review**.

## 6. Ticket

**This spec has no ticket yet, deliberately.** GGU-110, GGU-111 and GGU-112
were used in this session's commits and are numbers that were **invented**, not
assigned — the highest ticket referenced anywhere else in this repository is
GGU-109. They must be reconciled with Jira before this lands.
