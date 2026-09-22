# Frozen catalog contract

<!-- GENERATED FILE — do not edit by hand.
     Regenerate with: cd backend && make catalog -->

**Source of truth:** the projection registry in `backend/src/app/presentation/`,
under [ADR-K](../adr/ADR-K-response-shaping.md) D-14.
**Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) ·
**Spec:** [`specs/backend/0019-frozen-catalog-contract.md`](../../specs/backend/0019-frozen-catalog-contract.md)

This is the designer-facing field inventory GGU-41 asks for: for every catalog
component, the fields it receives, their format, whether they are required,
whether they arrive pre-formatted, which UI state they drive and which of them
are editable. It is **generated from the registry**, not transcribed from it.
A transcription is a second source of truth, and the second source is the one
that goes stale — which is the exact failure this contract exists to prevent.

Nothing needs copying out of here by hand either: the page the UI Kit binds to
is this file, cited by its projection ids and digests.

**For a machine, read the twin.** Markdown is for people, and a client test
cannot parse a table, so the same promise is rendered as JSON in
[`view-catalog.snapshot.json`](view-catalog.snapshot.json) — per view the
component type, the view id, the digest, the field paths, the options schema
and the rendered example (GGU-53, spec [`specs/backend/0021-machine-readable-catalog.md`](../../specs/backend/0021-machine-readable-catalog.md)). Both files come
out of one render pass over the registry and are gated by the same command, so
they cannot disagree with each other or with the code.

## What "frozen" means

Frozen does **not** mean a human promised not to change a field. It means
**drift is detected**:

- **A versioned id is immutable.** Once a client binds to
  `<component>.<variant>.v1`, that shape is fixed. A change arrives as a new id
  (`…v2`), never as a mutation of `v1` (ADR-K D-9).
- **A digest proves it.** Each component below carries a 12-character digest
  over everything it promises — id, summary, serving endpoints, options schema,
  payload schema and rendered example. That digest is the frozen version
  identifier the prompt fragments (GGU-14) and the Figma UI Kit cite. If a `v1`
  digest changes, something that was frozen moved.
- **The ship gate enforces it.** `make gate` re-renders this document from the
  registry and diffs it against the checked-in file. Any difference fails the
  gate and prints the command that fixes it:

  ```
  cd backend && make catalog
  ```

  So a projection cannot change without this file changing in the same commit,
  and a reviewer sees the moved field as a diff in the contract rather than
  discovering it after the design work is done.

## How to read the tables

Each component has two tables and one example.

**Options** — the knobs a caller may fill. Under ADR-K D-3 these are the *only*
inputs the system accepts: anything undeclared or out of range is a 422, never
a best-effort guess. *Type / format* is the schema's own wording; *Accepts* is
the sentence the generated prompt fragments teach the model (GGU-14), so
designer and model are held to the same bound, written once.

**Field inventory** — one row per field of the payload. The path is dotted;
`[]` marks a repeated row; parents appear before their children. The columns:

- **Field** — the dotted path, from the schema's `properties`, walked
  recursively.
- **Type / format** — the JSON type with its declared bound, from `type`,
  `const`, `enum`, `maxLength`, `maxItems` and `minimum`/`maximum`.
- **Presence** — whether the payload always carries the field, from the
  schema's `required` list and the field's default.
- **Binding** — how the client uses the value (below). Derived from structure,
  never from a hardcoded field name.
- **State** — which UI state the field can drive: an array can be `empty`, a
  nullable field can be `null`, an enum or boolean selects a `variant`.
- **Input** — the field is editable, and with what bounds. This is the one
  rule that reads a name, and it is spelled out under *Interactive components*.

**Binding** values, and how each is derived:

- `display` — a pre-formatted string the widget prints **verbatim**. A string
  leaf inside an object that holds a figure and this string **and nothing
  else**: the `*Display` pair of
  [ADR-E](../adr/ADR-E-money-representation.md) D-2, `{amount, display}` or
  `{value, display}`. Requiring the object to hold only the pair is what
  keeps a payload that carries a bare figure beside a title from having its
  title called pre-formatted.
- `raw` — the exact figure beside it, for a chart's geometry, **never
  printed**. Any leaf whose JSON type is numeric; a `Decimal` arrives as
  `number` or `string`.
- `text` — a server-written string with no numeric sibling: a title, a label, a
  sentence that already contains its numbers. Also bound verbatim.
- `enum` — a closed set the widget maps to a variant.
- `constant` — a fixed value, such as the `view` discriminator.
- `flag` — a boolean the widget switches on.
- `container` — an object or a list; its children carry the values.

The project's convention is that the pre-formatted member of a pair is named
`display`. The rule above keys on the **pair**, not on that name, so a pair
that names it otherwise is still classified correctly — and a bare figure that
no string accompanies shows up as `raw` with nothing to print, which is the
defect ADR-E D-5 forbids.

**Designers:** every figure a component shows is a `display` or a `text` cell.
If a number has to appear on screen and only `raw` carries it, the payload is
missing a field — raise it rather than formatting it in the client.

## Interactive components

A component is interactive when a value it renders can be changed and sent
back. Under ADR-K D-3 the only thing a caller may send is a **declared
option**, so an editable field is a payload field whose name matches an option
of the same projection: the widget shows it, the user edits it, the client
re-requests the same view with that option set. The **Input** column names the
option's bounds, and those bounds are the validation the design must respect —
the client does not invent its own.

A projection with no such match is read-only and every row reads `—`. A
component that needs an input which does **not** round-trip through a declared
option is a contract error rather than a missing column: the client would be
sending the backend something the registry cannot validate.

## States a component can be in

Three of the four states design needs are facts about the schema. One is not:

- **default** — the example payload of each component below.
- **empty** — every `empty` row in the State column is a list that can arrive
  with zero items.
- **variant** — every `variant` row is a closed set the widget switches on.
- **loading** and **error** are *transport* states, not payload states. No
  projection carries an `isLoading` flag: a surface is either streamed or not
  yet streamed (ADR-K D-19), and a failure arrives as an RFC 9457 problem
  document rather than as a payload with an error field. Design those two from
  the transport, not from this table.

## Components

| Frozen id | Component | Digest | Fields | Inputs | Purpose |
|---|---|---|---|---|---|
| [`activity.timeline.v1`](#activitytimelinev1) | `ActivityTimeline` | `dcb1032a4438` | 21 | `kind`, `groups[].entries[].kind` | The Activity tab: the ledger as a timeline grouped under today, this week and each month, filtered by kind, every row captioned and its amount signed the way the design colours it. |
| [`attribution.waterfall.v1`](#attributionwaterfallv1) | `AttributionWaterfall` | `a4926e77dfef` | 32 | read-only | Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first. |
| [`holdings.allocation.v1`](#holdingsallocationv1) | `HoldingsSummary` | `fa2cf78e5248` | 25 | `group_by` | Allocation of the portfolio's market value — by holding, asset class or sector — with weight and day change per slice, the count in the donut's centre, and the all-time gain under the total. |
| [`holdings.positions.v1`](#holdingspositionsv1) | `PositionList` | `279142f5554a` | 38 | read-only | The Holdings tab: total value with the all-time gain, then one row per position — shares and average cost, value, unrealised result, today's move, price and weight — each with the question that hands it to the assistant. |
| [`order.ticket.v1`](#orderticketv1) | `OrderTicket` | `d0daddcb8960` | 28 | `symbol`, `side`, `size`, `size_in` | Order ticket: a proposed buy or sell with its units, entry price and notional, plus the bounded inputs that re-render it. It places nothing. |
| [`payoff.curve.v1`](#payoffcurvev1) | `RiskPayoffChart` | `7066577b5390` | 32 | read-only | Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff. |
| [`portfolio.summary.v1`](#portfoliosummaryv1) | `PortfolioSummary` | `a7389adf90d7` | 39 | read-only | The Home hero: total value, the change over a selected period with its direction, a thirty-day sparkline, the owner's greeting, suggested questions for the assistant and the day's top movers. |
| [`scenario.comparison.v1`](#scenariocomparisonv1) | `ScenarioComparison` | `6f73ed9fad79` | 40 | `subject.symbol` | The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method. |
| [`taxlots.table.v1`](#taxlotstablev1) | `TaxLotTable` | `c960b55bd552` | 43 | read-only | Tax-lot table for a proposed sale: the lots it consumes under FIFO, LIFO or HIFO, each with its holding period, and the realised result split short-term vs long-term. Nothing is traded. |

## `activity.timeline.v1`

> The Activity tab: the ledger as a timeline grouped under today, this week and each month, filtered by kind, every row captioned and its amount signed the way the design colours it.

- **Frozen id:** `activity.timeline.v1` · **digest:** `dcb1032a4438`
- **Component:** `ActivityTimeline`
- **Payload type:** `ActivityTimelinePayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `kind`, `groups[].entries[].kind`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `kind` | enum all / buy / sell / dividend / deposit | one of 'all', 'buy', 'sell', 'dividend', 'deposit' | `"all"` | Which rows to show. |
| `limit` | integer 1..200 | integer 1..200 | `100` | Newest rows kept. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'activity.timeline.v1' | default `"activity.timeline.v1"` | `constant` | — | — |
| `title` | string ≤32 chars | default `"Activity"` | `text` | — | — |
| `note` | string ≤64 chars | default `"Simulated activity \u2014 resets each session."` | `text` | — | — |
| `kind` | enum all / buy / sell / dividend / deposit | required | `enum` | variant | input · one of 'all', 'buy', 'sell', 'dividend', 'deposit' |
| `filters` | array ≤8 items | default `[{"key": "all", "label": "All"}, {"key": "buy", "label": "Buys"}, {"key": "sell", "label": "Sells"}, {"key": "dividend", "label": "Dividends"}, {"key": "deposit", "label": "Deposits"}]` | `container` | empty | — |
| `filters[].key` | enum all / buy / sell / dividend / deposit | required | `enum` | variant | — |
| `filters[].label` | string ≤16 chars | required | `text` | — | — |
| `groups` | array ≤64 items | required | `container` | empty | — |
| `groups[].label` | string ≤24 chars | required | `text` | — | — |
| `groups[].entries` | array ≤200 items | required | `container` | empty | — |
| `groups[].entries[].key` | string ≤32 chars | required | `text` | — | — |
| `groups[].entries[].kind` | enum buy / sell / dividend / deposit | required | `enum` | variant | input · one of 'all', 'buy', 'sell', 'dividend', 'deposit' |
| `groups[].entries[].title` | string ≤48 chars | required | `text` | — | — |
| `groups[].entries[].detail` | string ≤64 chars | required | `text` | — | — |
| `groups[].entries[].amount` | object | required | `container` | — | — |
| `groups[].entries[].amount.amount` | decimal | required | `raw` | — | — |
| `groups[].entries[].amount.display` | string ≤32 chars | required | `display` | — | — |
| `groups[].entries[].tone` | enum up / down / flat | required | `enum` | variant | — |
| `groups[].entries[].badge` | string ≤12 chars | required | `text` | — | — |
| `groups[].entries[].realized` | object | default `null` | `text` | null | — |
| `groups[].entries[].term` | object | default `null` | `text` | null | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "activity.timeline.v1",
  "title": "Activity",
  "note": "Simulated activity \u2014 resets each session.",
  "kind": "all",
  "filters": [
    {
      "key": "all",
      "label": "All"
    },
    {
      "key": "buy",
      "label": "Buys"
    },
    {
      "key": "sell",
      "label": "Sells"
    },
    {
      "key": "dividend",
      "label": "Dividends"
    },
    {
      "key": "deposit",
      "label": "Deposits"
    }
  ],
  "groups": [
    {
      "label": "TODAY",
      "entries": [
        {
          "key": "txn-0017",
          "kind": "dividend",
          "title": "Dividend \u2014 VOO",
          "detail": "$1.62/sh \u00b7 85 sh \u00b7 qualified",
          "amount": {
            "amount": "137.70",
            "display": "+$137.70"
          },
          "tone": "up",
          "badge": "Dividend",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "THIS WEEK",
      "entries": [
        {
          "key": "txn-0018",
          "kind": "deposit",
          "title": "Deposit \u2014 Bank transfer",
          "detail": "Chase \u2022\u20224021 \u00b7 Tue",
          "amount": {
            "amount": "5000.00",
            "display": "+$5,000.00"
          },
          "tone": "up",
          "badge": "Deposit",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "JANUARY 2026",
      "entries": [
        {
          "key": "txn-0019",
          "kind": "dividend",
          "title": "Dividend \u2014 MSFT",
          "detail": "$0.83/sh \u00b7 110 sh \u00b7 qualified",
          "amount": {
            "amount": "91.30",
            "display": "+$91.30"
          },
          "tone": "up",
          "badge": "Dividend",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0020",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Jan 1",
          "amount": {
            "amount": "2500.00",
            "display": "+$2,500.00"
          },
          "tone": "up",
          "badge": "Deposit",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "DECEMBER 2025",
      "entries": [
        {
          "key": "txn-0021",
          "kind": "dividend",
          "title": "Dividend \u2014 AAPL",
          "detail": "$0.25/sh \u00b7 300 sh \u00b7 qualified",
          "amount": {
            "amount": "75.00",
            "display": "+$75.00"
          },
          "tone": "up",
          "badge": "Dividend",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "NOVEMBER 2025",
      "entries": [
        {
          "key": "txn-0022",
          "kind": "dividend",
          "title": "Dividend \u2014 JNJ",
          "detail": "$1.24/sh \u00b7 30 sh \u00b7 qualified",
          "amount": {
            "amount": "37.20",
            "display": "+$37.20"
          },
          "tone": "up",
          "badge": "Dividend",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "JUNE 2025",
      "entries": [
        {
          "key": "txn-0014",
          "kind": "buy",
          "title": "Bought 250 PYPL",
          "detail": "250 sh @ $88.60 \u00b7 Jun 19",
          "amount": {
            "amount": "-22150.00",
            "display": "-$22,150.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0015",
          "kind": "sell",
          "title": "Sold 20 VOO",
          "detail": "20 sh @ $489.00 \u00b7 Jun 19",
          "amount": {
            "amount": "9780.00",
            "display": "$9,780.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "1738.000000",
              "display": "+$1,738"
            },
            "text": "+$1,738 realized",
            "trend": "up"
          },
          "term": {
            "term": "short",
            "label": "ST gain"
          }
        }
      ]
    },
    {
      "label": "MARCH 2025",
      "entries": [
        {
          "key": "txn-0016",
          "kind": "buy",
          "title": "Bought 100 AAPL",
          "detail": "100 sh @ $95.40 \u00b7 Mar 21",
          "amount": {
            "amount": "-9540.00",
            "display": "-$9,540.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "JANUARY 2025",
      "entries": [
        {
          "key": "txn-0013",
          "kind": "buy",
          "title": "Bought 93 VNQ",
          "detail": "93 sh @ $106.51 \u00b7 Jan 30",
          "amount": {
            "amount": "-9905.43",
            "display": "-$9,905.43"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0012",
          "kind": "buy",
          "title": "Bought 30 NVDA",
          "detail": "30 sh @ $960.00 \u00b7 Jan 17",
          "amount": {
            "amount": "-28800.00",
            "display": "-$28,800.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0011",
          "kind": "buy",
          "title": "Bought 60 NVDA",
          "detail": "60 sh @ $760.00 \u00b7 Jan 13",
          "amount": {
            "amount": "-45600.00",
            "display": "-$45,600.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "DECEMBER 2024",
      "entries": [
        {
          "key": "txn-0010",
          "kind": "buy",
          "title": "Bought 250 GLD",
          "detail": "250 sh @ $240.00 \u00b7 Dec 21",
          "amount": {
            "amount": "-60000.00",
            "display": "-$60,000.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "NOVEMBER 2024",
      "entries": [
        {
          "key": "txn-0009",
          "kind": "buy",
          "title": "Bought 620 BND",
          "detail": "620 sh @ $74.10 \u00b7 Nov 11",
          "amount": {
            "amount": "-45942.00",
            "display": "-$45,942.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "OCTOBER 2024",
      "entries": [
        {
          "key": "txn-0008",
          "kind": "buy",
          "title": "Bought 30 TIP",
          "detail": "30 sh @ $135.00 \u00b7 Oct 12",
          "amount": {
            "amount": "-4050.00",
            "display": "-$4,050.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "SEPTEMBER 2024",
      "entries": [
        {
          "key": "txn-0007",
          "kind": "buy",
          "title": "Bought 130 XOM",
          "detail": "130 sh @ $42.00 \u00b7 Sep 22",
          "amount": {
            "amount": "-5460.00",
            "display": "-$5,460.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "AUGUST 2024",
      "entries": [
        {
          "key": "txn-0006",
          "kind": "buy",
          "title": "Bought 400 AGG",
          "detail": "400 sh @ $108.00 \u00b7 Aug 13",
          "amount": {
            "amount": "-43200.00",
            "display": "-$43,200.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "JULY 2024",
      "entries": [
        {
          "key": "txn-0005",
          "kind": "buy",
          "title": "Bought 105 VOO",
          "detail": "105 sh @ $402.10 \u00b7 Jul 24",
          "amount": {
            "amount": "-42220.50",
            "display": "-$42,220.50"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "MAY 2024",
      "entries": [
        {
          "key": "txn-0004",
          "kind": "buy",
          "title": "Bought 110 MSFT",
          "detail": "110 sh @ $305.20 \u00b7 May 15",
          "amount": {
            "amount": "-33572.00",
            "display": "-$33,572.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "MARCH 2024",
      "entries": [
        {
          "key": "txn-0003",
          "kind": "buy",
          "title": "Bought 25 PG",
          "detail": "25 sh @ $180.00 \u00b7 Mar 26",
          "amount": {
            "amount": "-4500.00",
            "display": "-$4,500.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "FEBRUARY 2024",
      "entries": [
        {
          "key": "txn-0002",
          "kind": "buy",
          "title": "Bought 30 JNJ",
          "detail": "30 sh @ $170.00 \u00b7 Feb 15",
          "amount": {
            "amount": "-5100.00",
            "display": "-$5,100.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "NOVEMBER 2023",
      "entries": [
        {
          "key": "txn-0001",
          "kind": "buy",
          "title": "Bought 200 AAPL",
          "detail": "200 sh @ $155.40 \u00b7 Nov 7",
          "amount": {
            "amount": "-31080.00",
            "display": "-$31,080.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        }
      ]
    }
  ]
}
```

## `attribution.waterfall.v1`

> Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first.

- **Frozen id:** `attribution.waterfall.v1` · **digest:** `a4926e77dfef`
- **Component:** `AttributionWaterfall`
- **Payload type:** `AttributionWaterfallPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `fields` | array ≤8 items | list of up to 8 (text), or omit it | `null` | Sections to render; omit for all of them. A section this view does not offer is rejected, never ignored. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'attribution.waterfall.v1' | default `"attribution.waterfall.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `start` | object | required | `container` | — | — |
| `start.label` | string ≤64 chars | required | `text` | — | — |
| `start.amount` | object | required | `container` | — | — |
| `start.amount.amount` | decimal | required | `raw` | — | — |
| `start.amount.display` | string ≤32 chars | required | `display` | — | — |
| `end` | object | required | `container` | — | — |
| `end.label` | string ≤64 chars | required | `text` | — | — |
| `end.amount` | object | required | `container` | — | — |
| `end.amount.amount` | decimal | required | `raw` | — | — |
| `end.amount.display` | string ≤32 chars | required | `display` | — | — |
| `buckets` | array | default `[]` | `container` | empty | — |
| `buckets[].label` | string ≤64 chars | required | `text` | — | — |
| `buckets[].key` | string ≤32 chars | required | `text` | — | — |
| `buckets[].delta` | object | required | `container` | — | — |
| `buckets[].delta.amount` | decimal | required | `raw` | — | — |
| `buckets[].delta.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].cumulative` | object | required | `container` | — | — |
| `buckets[].cumulative.amount` | decimal | required | `raw` | — | — |
| `buckets[].cumulative.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].direction` | enum up / down | required | `enum` | variant | — |
| `annotations` | array | default `[]` | `container` | empty | — |
| `annotations[].label` | string ≤64 chars | required | `text` | — | — |
| `annotations[].text` | string ≤200 chars | required | `text` | — | — |
| `actions` | array | default `[]` | `container` | empty | — |
| `actions[].action` | string ≤64 chars | required | `text` | — | — |
| `actions[].label` | string ≤64 chars | required | `text` | — | — |
| `actions[].arg` | string ≤32 chars | required | `text` | — | — |
| `actions[].control` | enum choice / text | required | `enum` | variant | — |
| `actions[].choices` | array ≤24 items | default `[]` | `container` | empty | — |
| `actions[].pattern` | string ≤64 chars | default `null` | `text` | null | — |

### When the agent picks this

- **Use it when** the user asks WHY a value changed and the answer decomposes into signed contributions that sum to a net delta — what drove the portfolio's result, profit and loss by position. The steps arrive largest move first; do not reorder them.
- **Do not use it for** a static breakdown of what is held now — `holdings.allocation.v1` answers that. Never write the figures yourself: render this view and copy the `display` strings it returns.

### Actions

| Action | Label | Argument | Control | Accepts |
|---|---|---|---|---|
| `drill.attribution.v1` | Break this down | `driver` | choice | 'AAPL', 'AGG', 'AMD', 'AVGO', 'BND', 'GLD', 'JNJ', 'MSFT', 'NVDA', 'PG', 'PYPL', 'TIP', 'TSLA', 'USD', 'VNQ', 'VOO', 'XOM' |

### Example payload

```json
{
  "view": "attribution.waterfall.v1",
  "title": "Unrealised P/L attribution",
  "start": {
    "label": "Cost basis",
    "amount": {
      "amount": "421711.15",
      "display": "$421,711.15"
    }
  },
  "end": {
    "label": "Market value",
    "amount": {
      "amount": "482915.200000",
      "display": "$482,915.20"
    }
  },
  "buckets": [
    {
      "label": "NVIDIA Corp",
      "key": "NVDA",
      "delta": {
        "amount": "34019.400000",
        "display": "$34,019.40"
      },
      "cumulative": {
        "amount": "455730.550000",
        "display": "$455,730.55"
      },
      "direction": "up"
    },
    {
      "label": "Apple Inc.",
      "key": "AAPL",
      "delta": {
        "amount": "29334.000000",
        "display": "$29,334.00"
      },
      "cumulative": {
        "amount": "485064.550000",
        "display": "$485,064.55"
      },
      "direction": "up"
    },
    {
      "label": "Microsoft Corp",
      "key": "MSFT",
      "delta": {
        "amount": "12958.000000",
        "display": "$12,958.00"
      },
      "cumulative": {
        "amount": "498022.550000",
        "display": "$498,022.55"
      },
      "direction": "up"
    },
    {
      "label": "Vanguard S&P 500 ETF",
      "key": "VOO",
      "delta": {
        "amount": "10701.500000",
        "display": "$10,701.50"
      },
      "cumulative": {
        "amount": "508724.050000",
        "display": "$508,724.05"
      },
      "direction": "up"
    },
    {
      "label": "SPDR Gold Shares",
      "key": "GLD",
      "delta": {
        "amount": "-10500.000000",
        "display": "-$10,500.00"
      },
      "cumulative": {
        "amount": "498224.050000",
        "display": "$498,224.05"
      },
      "direction": "down"
    },
    {
      "label": "PayPal Holdings",
      "key": "PYPL",
      "delta": {
        "amount": "-5825.000000",
        "display": "-$5,825.00"
      },
      "cumulative": {
        "amount": "492399.050000",
        "display": "$492,399.05"
      },
      "direction": "down"
    },
    {
      "label": "iShares Core US Aggregate Bond",
      "key": "AGG",
      "delta": {
        "amount": "-4200.000000",
        "display": "-$4,200.00"
      },
      "cumulative": {
        "amount": "488199.050000",
        "display": "$488,199.05"
      },
      "direction": "down"
    },
    {
      "label": "Vanguard Total Bond",
      "key": "BND",
      "delta": {
        "amount": "-1674.000000",
        "display": "-$1,674.00"
      },
      "cumulative": {
        "amount": "486525.050000",
        "display": "$486,525.05"
      },
      "direction": "down"
    },
    {
      "label": "Vanguard Real Estate",
      "key": "VNQ",
      "delta": {
        "amount": "-1455.450000",
        "display": "-$1,455.45"
      },
      "cumulative": {
        "amount": "485069.600000",
        "display": "$485,069.60"
      },
      "direction": "down"
    },
    {
      "label": "Exxon Mobil",
      "key": "XOM",
      "delta": {
        "amount": "-1011.400000",
        "display": "-$1,011.40"
      },
      "cumulative": {
        "amount": "484058.200000",
        "display": "$484,058.20"
      },
      "direction": "down"
    },
    {
      "label": "Johnson & Johnson",
      "key": "JNJ",
      "delta": {
        "amount": "-450.000000",
        "display": "-$450.00"
      },
      "cumulative": {
        "amount": "483608.200000",
        "display": "$483,608.20"
      },
      "direction": "down"
    },
    {
      "label": "iShares TIPS Bond",
      "key": "TIP",
      "delta": {
        "amount": "-393.000000",
        "display": "-$393.00"
      },
      "cumulative": {
        "amount": "483215.200000",
        "display": "$483,215.20"
      },
      "direction": "down"
    },
    {
      "label": "Procter & Gamble",
      "key": "PG",
      "delta": {
        "amount": "-300.000000",
        "display": "-$300.00"
      },
      "cumulative": {
        "amount": "482915.200000",
        "display": "$482,915.20"
      },
      "direction": "down"
    },
    {
      "label": "Cash & sweep",
      "key": "USD",
      "delta": {
        "amount": "0.000000",
        "display": "$0.00"
      },
      "cumulative": {
        "amount": "482915.200000",
        "display": "$482,915.20"
      },
      "direction": "up"
    }
  ],
  "annotations": [
    {
      "label": "NVIDIA Corp",
      "text": "$34,019.40"
    },
    {
      "label": "Apple Inc.",
      "text": "$29,334.00"
    },
    {
      "label": "Net",
      "text": "$61,204.05"
    }
  ],
  "actions": [
    {
      "action": "drill.attribution.v1",
      "label": "Break this down",
      "arg": "driver",
      "control": "choice",
      "choices": [
        "AAPL",
        "AGG",
        "AMD",
        "AVGO",
        "BND",
        "GLD",
        "JNJ",
        "MSFT",
        "NVDA",
        "PG",
        "PYPL",
        "TIP",
        "TSLA",
        "USD",
        "VNQ",
        "VOO",
        "XOM"
      ],
      "pattern": null
    }
  ]
}
```

## `holdings.allocation.v1`

> Allocation of the portfolio's market value — by holding, asset class or sector — with weight and day change per slice, the count in the donut's centre, and the all-time gain under the total.

- **Frozen id:** `holdings.allocation.v1` · **digest:** `fa2cf78e5248`
- **Component:** `HoldingsSummary`
- **Payload type:** `HoldingsAllocationPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `group_by`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `top_n` | integer 1..20 | integer 1..20 | `5` | How many rows to render before the residual bucket. |
| `include_other` | boolean | true or false | `true` | Aggregate everything beyond `top_n` into an `Other` row. |
| `sort` | enum value_desc / value_asc / label | one of 'value_desc', 'value_asc', 'label' | `"value_desc"` | Row order: by value descending, ascending, or by label. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `group_by` | enum holding / asset_class / sector | one of 'holding', 'asset_class', 'sector' | `"holding"` | How the donut is sliced. `holding` is one slice per position; `asset_class` folds them into Equities, Bonds, Cash and Alternatives; `sector` folds the equities by sector. |
| `headline` | boolean | true or false | `true` | Carry the total and all-time gain block. The Home card draws the donut under the shell's own hero, so it asks for `false`. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'holdings.allocation.v1' | default `"holdings.allocation.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `group_by` | enum holding / asset_class / sector | required | `enum` | variant | input · one of 'holding', 'asset_class', 'sector' |
| `total` | object | required | `container` | — | — |
| `total.label` | string ≤64 chars | required | `text` | — | — |
| `total.amount` | object | required | `container` | — | — |
| `total.amount.amount` | decimal | required | `raw` | — | — |
| `total.amount.display` | string ≤32 chars | required | `display` | — | — |
| `total_gain` | object | default `null` | `text` | null | — |
| `center` | object | required | `container` | — | — |
| `center.count` | string ≤4 chars | required | `text` | — | — |
| `center.unit` | string ≤16 chars | required | `text` | — | — |
| `categories` | array | required | `container` | empty | — |
| `categories[].label` | string ≤64 chars | required | `text` | — | — |
| `categories[].key` | string ≤32 chars | required | `text` | — | — |
| `categories[].value` | object | required | `container` | — | — |
| `categories[].value.amount` | decimal | required | `raw` | — | — |
| `categories[].value.display` | string ≤32 chars | required | `display` | — | — |
| `categories[].weight` | object | required | `container` | — | — |
| `categories[].weight.value` | decimal | required | `raw` | — | — |
| `categories[].weight.display` | string ≤16 chars | required | `display` | — | — |
| `categories[].change` | object | required | `container` | — | — |
| `categories[].change.value` | decimal | required | `raw` | — | — |
| `categories[].change.display` | string ≤16 chars | required | `display` | — | — |
| `categories[].trend` | enum up / down / flat | required | `enum` | variant | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "holdings.allocation.v1",
  "title": "Allocation by holding",
  "group_by": "holding",
  "total": {
    "label": "Total market value",
    "amount": {
      "amount": "482915.200000",
      "display": "$482,915.20"
    }
  },
  "total_gain": {
    "amount": {
      "amount": "61204.050000",
      "display": "+$61,204"
    },
    "percent": {
      "value": "0.1451326340316114477883736297",
      "display": "+14.5%"
    },
    "trend": "up",
    "period": "all-time"
  },
  "center": {
    "count": "14",
    "unit": "Holdings"
  },
  "categories": [
    {
      "label": "NVIDIA Corp",
      "key": "NVDA",
      "value": {
        "amount": "108419.400000",
        "display": "$108,419.40"
      },
      "weight": {
        "value": "0.2245102245694482178237504224",
        "display": "22.45%"
      },
      "change": {
        "value": "0.04200328691289680823458178358",
        "display": "+4.2%"
      },
      "trend": "up"
    },
    {
      "label": "Apple Inc.",
      "key": "AAPL",
      "value": {
        "amount": "69954.000000",
        "display": "$69,954.00"
      },
      "weight": {
        "value": "0.1448577307154548044874131110",
        "display": "14.49%"
      },
      "change": {
        "value": "0.01101283385362469649670482137",
        "display": "+1.1%"
      },
      "trend": "up"
    },
    {
      "label": "SPDR Gold Shares",
      "key": "GLD",
      "value": {
        "amount": "49500.000000",
        "display": "$49,500.00"
      },
      "weight": {
        "value": "0.1025024683422679592607563398",
        "display": "10.25%"
      },
      "change": {
        "value": "0.01382488479262672811059907834",
        "display": "+1.4%"
      },
      "trend": "up"
    },
    {
      "label": "Microsoft Corp",
      "key": "MSFT",
      "value": {
        "amount": "46530.000000",
        "display": "$46,530.00"
      },
      "weight": {
        "value": "0.09635232024173188170511095944",
        "display": "9.64%"
      },
      "change": {
        "value": "-0.0005198242049052502244695430273",
        "display": "-0.1%"
      },
      "trend": "down"
    },
    {
      "label": "Vanguard S&P 500 ETF",
      "key": "VOO",
      "value": {
        "amount": "44880.000000",
        "display": "$44,880.00"
      },
      "weight": {
        "value": "0.09293557129698961639641908145",
        "display": "9.29%"
      },
      "change": {
        "value": "-0.04864864864864864864864864865",
        "display": "-4.9%"
      },
      "trend": "down"
    },
    {
      "label": "Other",
      "key": "other",
      "value": {
        "amount": "163631.800000",
        "display": "$163,631.80"
      },
      "weight": {
        "value": "0.3388416848341075203265500858",
        "display": "33.88%"
      },
      "change": {
        "value": "-0.001513426119213457764354390919",
        "display": "-0.2%"
      },
      "trend": "down"
    }
  ]
}
```

## `holdings.positions.v1`

> The Holdings tab: total value with the all-time gain, then one row per position — shares and average cost, value, unrealised result, today's move, price and weight — each with the question that hands it to the assistant.

- **Frozen id:** `holdings.positions.v1` · **digest:** `279142f5554a`
- **Component:** `PositionList`
- **Payload type:** `HoldingsPositionsPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `sort` | enum value_desc / value_asc / label | one of 'value_desc', 'value_asc', 'label' | `"value_desc"` | Row order: by value descending, ascending, or by label. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'holdings.positions.v1' | default `"holdings.positions.v1"` | `constant` | — | — |
| `title` | string ≤32 chars | default `"Holdings"` | `text` | — | — |
| `total` | object | required | `container` | — | — |
| `total.label` | string ≤64 chars | required | `text` | — | — |
| `total.amount` | object | required | `container` | — | — |
| `total.amount.amount` | decimal | required | `raw` | — | — |
| `total.amount.display` | string ≤32 chars | required | `display` | — | — |
| `gain` | object | required | `container` | — | — |
| `gain.amount` | object | required | `container` | — | — |
| `gain.amount.amount` | decimal | required | `raw` | — | — |
| `gain.amount.display` | string ≤32 chars | required | `display` | — | — |
| `gain.percent` | object | required | `container` | — | — |
| `gain.percent.value` | decimal | required | `raw` | — | — |
| `gain.percent.display` | string ≤16 chars | required | `display` | — | — |
| `gain.trend` | enum up / down / flat | required | `enum` | variant | — |
| `gain.period` | string ≤24 chars | required | `text` | — | — |
| `ask_label` | string ≤48 chars | default `"Ask the assistant about this"` | `text` | — | — |
| `positions` | array ≤64 items | required | `container` | empty | — |
| `positions[].symbol` | string ≤10 chars | required | `text` | — | — |
| `positions[].name` | string ≤64 chars | required | `text` | — | — |
| `positions[].detail` | string ≤48 chars | required | `text` | — | — |
| `positions[].value` | object | required | `container` | — | — |
| `positions[].value.amount` | decimal | required | `raw` | — | — |
| `positions[].value.display` | string ≤32 chars | required | `display` | — | — |
| `positions[].unrealized` | object | default `null` | `text` | null | — |
| `positions[].day` | object | required | `container` | — | — |
| `positions[].day.value` | decimal | required | `raw` | — | — |
| `positions[].day.display` | string ≤16 chars | required | `display` | — | — |
| `positions[].day_trend` | enum up / down / flat | required | `enum` | variant | — |
| `positions[].price` | object | required | `container` | — | — |
| `positions[].price.amount` | decimal | required | `raw` | — | — |
| `positions[].price.display` | string ≤32 chars | required | `display` | — | — |
| `positions[].weight` | object | required | `container` | — | — |
| `positions[].weight.value` | decimal | required | `raw` | — | — |
| `positions[].weight.display` | string ≤16 chars | required | `display` | — | — |
| `positions[].is_cash` | boolean | required | `flag` | variant | — |
| `positions[].ask` | object | required | `container` | — | — |
| `positions[].ask.text` | string ≤80 chars | required | `text` | — | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "holdings.positions.v1",
  "title": "Holdings",
  "total": {
    "label": "Total value",
    "amount": {
      "amount": "482915.200000",
      "display": "$482,915.20"
    }
  },
  "gain": {
    "amount": {
      "amount": "61204.050000",
      "display": "+$61,204"
    },
    "percent": {
      "value": "0.1451326340316114477883736297",
      "display": "+14.5%"
    },
    "trend": "up",
    "period": "all-time unrealized"
  },
  "ask_label": "Ask the assistant about this",
  "positions": [
    {
      "symbol": "NVDA",
      "name": "NVIDIA Corp",
      "detail": "90 sh \u00b7 avg $826.67",
      "value": {
        "amount": "108419.400000",
        "display": "$108,419.40"
      },
      "unrealized": {
        "amount": {
          "amount": "34019.400000",
          "display": "+$34,019"
        },
        "percent": {
          "value": "0.45725",
          "display": "+45.7%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "0.04200328691289680823458178358",
        "display": "+4.2%"
      },
      "day_trend": "up",
      "price": {
        "amount": "1204.66",
        "display": "$1,204.66"
      },
      "weight": {
        "value": "0.2245102245694482178237504224",
        "display": "22.5%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my NVDA position"
      }
    },
    {
      "symbol": "AAPL",
      "name": "Apple Inc.",
      "detail": "300 sh \u00b7 avg $135.40",
      "value": {
        "amount": "69954.000000",
        "display": "$69,954.00"
      },
      "unrealized": {
        "amount": {
          "amount": "29334.000000",
          "display": "+$29,334"
        },
        "percent": {
          "value": "0.7221565731166912850812407681",
          "display": "+72.2%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "0.01101283385362469649670482137",
        "display": "+1.1%"
      },
      "day_trend": "up",
      "price": {
        "amount": "233.18",
        "display": "$233.18"
      },
      "weight": {
        "value": "0.1448577307154548044874131110",
        "display": "14.5%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my AAPL position"
      }
    },
    {
      "symbol": "GLD",
      "name": "SPDR Gold Shares",
      "detail": "250 sh \u00b7 avg $240.00",
      "value": {
        "amount": "49500.000000",
        "display": "$49,500.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-10500.000000",
          "display": "-$10,500"
        },
        "percent": {
          "value": "-0.1750",
          "display": "-17.5%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "0.01382488479262672811059907834",
        "display": "+1.4%"
      },
      "day_trend": "up",
      "price": {
        "amount": "198.00",
        "display": "$198.00"
      },
      "weight": {
        "value": "0.1025024683422679592607563398",
        "display": "10.3%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my GLD position"
      }
    },
    {
      "symbol": "MSFT",
      "name": "Microsoft Corp",
      "detail": "110 sh \u00b7 avg $305.20",
      "value": {
        "amount": "46530.000000",
        "display": "$46,530.00"
      },
      "unrealized": {
        "amount": {
          "amount": "12958.000000",
          "display": "+$12,958"
        },
        "percent": {
          "value": "0.3859764089121887287024901704",
          "display": "+38.6%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "-0.0005198242049052502244695430273",
        "display": "-0.1%"
      },
      "day_trend": "down",
      "price": {
        "amount": "423.00",
        "display": "$423.00"
      },
      "weight": {
        "value": "0.09635232024173188170511095944",
        "display": "9.6%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my MSFT position"
      }
    },
    {
      "symbol": "VOO",
      "name": "Vanguard S&P 500 ETF",
      "detail": "85 sh \u00b7 avg $402.10",
      "value": {
        "amount": "44880.000000",
        "display": "$44,880.00"
      },
      "unrealized": {
        "amount": {
          "amount": "10701.500000",
          "display": "+$10,702"
        },
        "percent": {
          "value": "0.3131061924894304899278786372",
          "display": "+31.3%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "-0.04864864864864864864864864865",
        "display": "-4.9%"
      },
      "day_trend": "down",
      "price": {
        "amount": "528.00",
        "display": "$528.00"
      },
      "weight": {
        "value": "0.09293557129698961639641908145",
        "display": "9.3%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my VOO position"
      }
    },
    {
      "symbol": "BND",
      "name": "Vanguard Total Bond",
      "detail": "620 sh \u00b7 avg $74.10",
      "value": {
        "amount": "44268.000000",
        "display": "$44,268.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-1674.000000",
          "display": "-$1,674"
        },
        "percent": {
          "value": "-0.03643724696356275303643724696",
          "display": "-3.6%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.002096436058700209643605870021",
        "display": "-0.2%"
      },
      "day_trend": "down",
      "price": {
        "amount": "71.40",
        "display": "$71.40"
      },
      "weight": {
        "value": "0.09166826805203066708192245761",
        "display": "9.2%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my BND position"
      }
    },
    {
      "symbol": "AGG",
      "name": "iShares Core US Aggregate Bond",
      "detail": "400 sh \u00b7 avg $108.00",
      "value": {
        "amount": "39000.000000",
        "display": "$39,000.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-4200.000000",
          "display": "-$4,200"
        },
        "percent": {
          "value": "-0.09722222222222222222222222222",
          "display": "-9.7%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.002047082906857727737973387922",
        "display": "-0.2%"
      },
      "day_trend": "down",
      "price": {
        "amount": "97.50",
        "display": "$97.50"
      },
      "weight": {
        "value": "0.08075952051208990729635347987",
        "display": "8.1%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my AGG position"
      }
    },
    {
      "symbol": "PYPL",
      "name": "PayPal Holdings",
      "detail": "250 sh \u00b7 avg $88.60",
      "value": {
        "amount": "16325.000000",
        "display": "$16,325.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-5825.000000",
          "display": "-$5,825"
        },
        "percent": {
          "value": "-0.2629796839729119638826185102",
          "display": "-26.3%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.003813882532418001525553012967",
        "display": "-0.4%"
      },
      "day_trend": "down",
      "price": {
        "amount": "65.30",
        "display": "$65.30"
      },
      "weight": {
        "value": "0.03380510698358635222084539894",
        "display": "3.4%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my PYPL position"
      }
    },
    {
      "symbol": "VNQ",
      "name": "Vanguard Real Estate",
      "detail": "93 sh \u00b7 avg $106.51",
      "value": {
        "amount": "8449.980000",
        "display": "$8,449.98"
      },
      "unrealized": {
        "amount": {
          "amount": "-1455.450000",
          "display": "-$1,455"
        },
        "percent": {
          "value": "-0.1469345601351985729039526805",
          "display": "-14.7%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "0.01519553072625698324022346369",
        "display": "+1.5%"
      },
      "day_trend": "up",
      "price": {
        "amount": "90.86",
        "display": "$90.86"
      },
      "weight": {
        "value": "0.01749785469581408909887284558",
        "display": "1.7%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my VNQ position"
      }
    },
    {
      "symbol": "JNJ",
      "name": "Johnson & Johnson",
      "detail": "30 sh \u00b7 avg $170.00",
      "value": {
        "amount": "4650.000000",
        "display": "$4,650.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-450.000000",
          "display": "-$450"
        },
        "percent": {
          "value": "-0.08823529411764705882352941176",
          "display": "-8.8%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.009900990099009900990099009901",
        "display": "-1.0%"
      },
      "day_trend": "down",
      "price": {
        "amount": "155.00",
        "display": "$155.00"
      },
      "weight": {
        "value": "0.009629019753364565869949837984",
        "display": "1.0%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my JNJ position"
      }
    },
    {
      "symbol": "XOM",
      "name": "Exxon Mobil",
      "detail": "130 sh \u00b7 avg $42.00",
      "value": {
        "amount": "4448.600000",
        "display": "$4,448.60"
      },
      "unrealized": {
        "amount": {
          "amount": "-1011.400000",
          "display": "-$1,011"
        },
        "percent": {
          "value": "-0.1852380952380952380952380952",
          "display": "-18.5%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.01012438530517789991321955453",
        "display": "-1.0%"
      },
      "day_trend": "down",
      "price": {
        "amount": "34.22",
        "display": "$34.22"
      },
      "weight": {
        "value": "0.009211969306412388758937386937",
        "display": "0.9%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my XOM position"
      }
    },
    {
      "symbol": "PG",
      "name": "Procter & Gamble",
      "detail": "25 sh \u00b7 avg $180.00",
      "value": {
        "amount": "4200.000000",
        "display": "$4,200.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-300.000000",
          "display": "-$300"
        },
        "percent": {
          "value": "-0.06666666666666666666666666667",
          "display": "-6.7%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.01001767825574543311726576311",
        "display": "-1.0%"
      },
      "day_trend": "down",
      "price": {
        "amount": "168.00",
        "display": "$168.00"
      },
      "weight": {
        "value": "0.008697179132071220785761143986",
        "display": "0.9%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my PG position"
      }
    },
    {
      "symbol": "TIP",
      "name": "iShares TIPS Bond",
      "detail": "30 sh \u00b7 avg $135.00",
      "value": {
        "amount": "3657.000000",
        "display": "$3,657.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-393.000000",
          "display": "-$393"
        },
        "percent": {
          "value": "-0.09703703703703703703703703704",
          "display": "-9.7%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.001229004506349856616140925850",
        "display": "-0.1%"
      },
      "day_trend": "down",
      "price": {
        "amount": "121.90",
        "display": "$121.90"
      },
      "weight": {
        "value": "0.007572758115710584384173453227",
        "display": "0.8%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my TIP position"
      }
    },
    {
      "symbol": "USD",
      "name": "Cash & sweep",
      "detail": "Settlement fund",
      "value": {
        "amount": "38633.220000",
        "display": "$38,633.22"
      },
      "unrealized": null,
      "day": {
        "value": "0",
        "display": "0.0%"
      },
      "day_trend": "flat",
      "price": {
        "amount": "1.00",
        "display": "$1.00"
      },
      "weight": {
        "value": "0.08000000828302774482973408168",
        "display": "8.0%"
      },
      "is_cash": true,
      "ask": {
        "text": "What is my cash doing?"
      }
    }
  ]
}
```

## `order.ticket.v1`

> Order ticket: a proposed buy or sell with its units, entry price and notional, plus the bounded inputs that re-render it. It places nothing.

- **Frozen id:** `order.ticket.v1` · **digest:** `d0daddcb8960`
- **Component:** `OrderTicket`
- **Payload type:** `OrderTicketPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `symbol`, `side`, `size`, `size_in`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | enum AAPL / AGG / AMD / AVGO / BND / GLD / JNJ / MSFT / NVDA / PG / PYPL / TIP / TSLA / USD / VNQ / VOO / XOM | one of 'AAPL', 'AGG', 'AMD', 'AVGO', 'BND', 'GLD', 'JNJ', 'MSFT', 'NVDA', 'PG', 'PYPL', 'TIP', 'TSLA', 'USD', 'VNQ', 'VOO', 'XOM' | `"NVDA"` | Asset the order is written for, from the market reference. |
| `side` | enum buy / sell | one of 'buy', 'sell' | `"buy"` | Which way the order goes; `sell` disposes of units held. |
| `size` | string | string matching ^[0-9]{1,9}(\.[0-9]{1,8})?$ | `"1"` | How big the order is, as a decimal string (ADR-E D-5). |
| `size_in` | enum units / usd | one of 'units', 'usd' | `"units"` | What `size` counts: units of the asset, or US dollars. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'order.ticket.v1' | default `"order.ticket.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `symbol` | string ≤10 chars | required | `text` | — | input · one of 'AAPL', 'AGG', 'AMD', 'AVGO', 'BND', 'GLD', 'JNJ', 'MSFT', 'NVDA', 'PG', 'PYPL', 'TIP', 'TSLA', 'USD', 'VNQ', 'VOO', 'XOM' |
| `name` | string ≤64 chars | required | `text` | — | — |
| `side` | enum buy / sell | required | `enum` | variant | input · one of 'buy', 'sell' |
| `size` | string ≤32 chars | required | `text` | — | input · string matching ^[0-9]{1,9}(\.[0-9]{1,8})?$ |
| `size_in` | enum units / usd | required | `enum` | variant | input · one of 'units', 'usd' |
| `quantity` | object | required | `container` | — | — |
| `quantity.units` | decimal | required | `raw` | — | — |
| `quantity.display` | string ≤32 chars | required | `display` | — | — |
| `entry_price` | object | required | `container` | — | — |
| `entry_price.amount` | decimal | required | `raw` | — | — |
| `entry_price.display` | string ≤32 chars | required | `display` | — | — |
| `notional` | object | required | `container` | — | — |
| `notional.label` | string ≤64 chars | required | `text` | — | — |
| `notional.amount` | object | required | `container` | — | — |
| `notional.amount.amount` | decimal | required | `raw` | — | — |
| `notional.amount.display` | string ≤32 chars | required | `display` | — | — |
| `inputs` | array | required | `container` | empty | — |
| `inputs[].option` | string ≤32 chars | required | `text` | — | — |
| `inputs[].label` | string ≤64 chars | required | `text` | — | — |
| `inputs[].control` | enum choice / text | required | `enum` | variant | — |
| `inputs[].value` | string ≤32 chars | required | `text` | — | — |
| `inputs[].choices` | array ≤24 items | default `[]` | `container` | empty | — |
| `inputs[].pattern` | string ≤64 chars | default `null` | `text` | null | — |
| `inputs[].hint` | string ≤64 chars | default `null` | `text` | null | — |
| `effect` | const 'recalculate' | default `"recalculate"` | `constant` | — | — |
| `disclosure` | string ≤300 chars | required | `text` | — | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "order.ticket.v1",
  "title": "Proposed order",
  "symbol": "NVDA",
  "name": "NVIDIA Corp",
  "side": "buy",
  "size": "1",
  "size_in": "units",
  "quantity": {
    "units": "1",
    "display": "1"
  },
  "entry_price": {
    "amount": "1204.66",
    "display": "$1,204.66"
  },
  "notional": {
    "label": "Order value",
    "amount": {
      "amount": "1204.66",
      "display": "$1,204.66"
    }
  },
  "inputs": [
    {
      "option": "symbol",
      "label": "Asset",
      "control": "choice",
      "value": "NVDA",
      "choices": [
        "AAPL",
        "AGG",
        "AMD",
        "AVGO",
        "BND",
        "GLD",
        "JNJ",
        "MSFT",
        "NVDA",
        "PG",
        "PYPL",
        "TIP",
        "TSLA",
        "USD",
        "VNQ",
        "VOO",
        "XOM"
      ],
      "pattern": null,
      "hint": null
    },
    {
      "option": "side",
      "label": "Side",
      "control": "choice",
      "value": "buy",
      "choices": [
        "buy",
        "sell"
      ],
      "pattern": null,
      "hint": null
    },
    {
      "option": "size",
      "label": "Size",
      "control": "text",
      "value": "1",
      "choices": [],
      "pattern": "^[0-9]{1,9}(\\.[0-9]{1,8})?$",
      "hint": "Up to 8 decimal places"
    },
    {
      "option": "size_in",
      "label": "Size in",
      "control": "choice",
      "value": "units",
      "choices": [
        "units",
        "usd"
      ],
      "pattern": null,
      "hint": null
    }
  ],
  "effect": "recalculate",
  "disclosure": "Illustrative ticket. This showcase has no broker and no execution: changing a field re-renders these figures, and nothing is ever sent, placed or settled."
}
```

## `payoff.curve.v1`

> Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff.

- **Frozen id:** `payoff.curve.v1` · **digest:** `7066577b5390`
- **Component:** `RiskPayoffChart`
- **Payload type:** `PayoffCurvePayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `fields` | array ≤8 items | list of up to 8 (text), or omit it | `null` | Sections to render; omit for all of them. A section this view does not offer is rejected, never ignored. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | enum AAPL / AGG / AMD / AVGO / BND / GLD / JNJ / MSFT / NVDA / PG / PYPL / TIP / TSLA / USD / VNQ / VOO / XOM | one of 'AAPL', 'AGG', 'AMD', 'AVGO', 'BND', 'GLD', 'JNJ', 'MSFT', 'NVDA', 'PG', 'PYPL', 'TIP', 'TSLA', 'USD', 'VNQ', 'VOO', 'XOM' | `"VOO"` | Asset the order is for. |
| `size` | integer 1..1000000000 | integer 1..1000000000 | `500` | How big the order is, counted in `size_in`. A whole number: a JSON float can no longer be made exact (ADR-E D-5). |
| `size_in` | enum units / usd | one of 'units', 'usd' | `"usd"` | What `size` counts: units of the asset, or US dollars. |
| `side` | enum buy / sell | one of 'buy', 'sell' | `"buy"` | `buy` plots the position, `sell` plots its mirror. |
| `range_pct` | integer 5..90 | integer 5..90 | `30` | How far above and below the entry price to plot, in percent. |
| `steps` | integer 1..25 | integer 1..25 | `12` | Price steps per side; the line is twice this plus one point. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'payoff.curve.v1' | default `"payoff.curve.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `disclosure` | string ≤400 chars | required | `text` | — | — |
| `markers` | object | required | `container` | — | — |
| `markers.break_even` | object | required | `container` | — | — |
| `markers.break_even.label` | string ≤64 chars | required | `text` | — | — |
| `markers.break_even.at` | object | required | `container` | — | — |
| `markers.break_even.at.amount` | decimal | required | `raw` | — | — |
| `markers.break_even.at.display` | string ≤32 chars | required | `display` | — | — |
| `markers.current` | object | required | `container` | — | — |
| `markers.current.label` | string ≤64 chars | required | `text` | — | — |
| `markers.current.at` | object | required | `container` | — | — |
| `markers.current.at.amount` | decimal | required | `raw` | — | — |
| `markers.current.at.display` | string ≤32 chars | required | `display` | — | — |
| `totals` | array | default `[]` | `container` | empty | — |
| `totals[].label` | string ≤64 chars | required | `text` | — | — |
| `totals[].amount` | object | required | `container` | — | — |
| `totals[].amount.amount` | decimal | required | `raw` | — | — |
| `totals[].amount.display` | string ≤32 chars | required | `display` | — | — |
| `series` | array | default `[]` | `container` | empty | — |
| `series[].name` | string ≤64 chars | required | `text` | — | — |
| `series[].points` | array | required | `container` | empty | — |
| `series[].points[].label` | string ≤64 chars | required | `text` | — | — |
| `series[].points[].at` | object | required | `container` | — | — |
| `series[].points[].at.amount` | decimal | required | `raw` | — | — |
| `series[].points[].at.display` | string ≤32 chars | required | `display` | — | — |
| `series[].points[].value` | object | required | `container` | — | — |
| `series[].points[].value.amount` | decimal | required | `raw` | — | — |
| `series[].points[].value.display` | string ≤32 chars | required | `display` | — | — |
| `annotations` | array | default `[]` | `container` | empty | — |
| `annotations[].label` | string ≤64 chars | required | `text` | — | — |
| `annotations[].text` | string ≤200 chars | required | `text` | — | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "payoff.curve.v1",
  "title": "Payoff across a price range: buy Vanguard S&P 500 ETF",
  "disclosure": "Illustrative linear spot payoff on the demo portfolio's simulated prices: profit or loss is (price - entry) x quantity, with no fees, no slippage and no financing. There is no strike, no expiry, no implied volatility and no time decay behind this line. A sell is the mirror of the position and leaves no position to value.",
  "markers": {
    "break_even": {
      "label": "Break-even",
      "at": {
        "amount": "528.00",
        "display": "$528.00"
      }
    },
    "current": {
      "label": "Current price",
      "at": {
        "amount": "528.00",
        "display": "$528.00"
      }
    }
  },
  "totals": [
    {
      "label": "Entry price",
      "amount": {
        "amount": "528.00",
        "display": "$528.00"
      }
    },
    {
      "label": "Break-even price",
      "amount": {
        "amount": "528.00",
        "display": "$528.00"
      }
    },
    {
      "label": "Notional",
      "amount": {
        "amount": "500.0000000000000000000000000",
        "display": "$500.00"
      }
    }
  ],
  "series": [
    {
      "name": "Profit / loss",
      "points": [
        {
          "label": "$369.60",
          "at": {
            "amount": "369.600",
            "display": "$369.60"
          },
          "value": {
            "amount": "-150.0000000000000000000000000",
            "display": "-$150.00"
          }
        },
        {
          "label": "$382.80",
          "at": {
            "amount": "382.80000",
            "display": "$382.80"
          },
          "value": {
            "amount": "-137.5000000000000000000000000",
            "display": "-$137.50"
          }
        },
        {
          "label": "$396.00",
          "at": {
            "amount": "396.0000",
            "display": "$396.00"
          },
          "value": {
            "amount": "-125.0000000000000000000000000",
            "display": "-$125.00"
          }
        },
        {
          "label": "$409.20",
          "at": {
            "amount": "409.20000",
            "display": "$409.20"
          },
          "value": {
            "amount": "-112.5000000000000000000000000",
            "display": "-$112.50"
          }
        },
        {
          "label": "$422.40",
          "at": {
            "amount": "422.400",
            "display": "$422.40"
          },
          "value": {
            "amount": "-100.0000000000000000000000000",
            "display": "-$100.00"
          }
        },
        {
          "label": "$435.60",
          "at": {
            "amount": "435.60000",
            "display": "$435.60"
          },
          "value": {
            "amount": "-87.50000000000000000000000000",
            "display": "-$87.50"
          }
        },
        {
          "label": "$448.80",
          "at": {
            "amount": "448.8000",
            "display": "$448.80"
          },
          "value": {
            "amount": "-75.00000000000000000000000000",
            "display": "-$75.00"
          }
        },
        {
          "label": "$462.00",
          "at": {
            "amount": "462.00000",
            "display": "$462.00"
          },
          "value": {
            "amount": "-62.50000000000000000000000000",
            "display": "-$62.50"
          }
        },
        {
          "label": "$475.20",
          "at": {
            "amount": "475.200",
            "display": "$475.20"
          },
          "value": {
            "amount": "-50.00000000000000000000000000",
            "display": "-$50.00"
          }
        },
        {
          "label": "$488.40",
          "at": {
            "amount": "488.40000",
            "display": "$488.40"
          },
          "value": {
            "amount": "-37.50000000000000000000000000",
            "display": "-$37.50"
          }
        },
        {
          "label": "$501.60",
          "at": {
            "amount": "501.6000",
            "display": "$501.60"
          },
          "value": {
            "amount": "-25.00000000000000000000000000",
            "display": "-$25.00"
          }
        },
        {
          "label": "$514.80",
          "at": {
            "amount": "514.80000",
            "display": "$514.80"
          },
          "value": {
            "amount": "-12.50000000000000000000000000",
            "display": "-$12.50"
          }
        },
        {
          "label": "$528.00",
          "at": {
            "amount": "528.000",
            "display": "$528.00"
          },
          "value": {
            "amount": "0E-31",
            "display": "$0.00"
          }
        },
        {
          "label": "$541.20",
          "at": {
            "amount": "541.20000",
            "display": "$541.20"
          },
          "value": {
            "amount": "12.50000000000000000000000000",
            "display": "$12.50"
          }
        },
        {
          "label": "$554.40",
          "at": {
            "amount": "554.4000",
            "display": "$554.40"
          },
          "value": {
            "amount": "25.00000000000000000000000000",
            "display": "$25.00"
          }
        },
        {
          "label": "$567.60",
          "at": {
            "amount": "567.60000",
            "display": "$567.60"
          },
          "value": {
            "amount": "37.50000000000000000000000000",
            "display": "$37.50"
          }
        },
        {
          "label": "$580.80",
          "at": {
            "amount": "580.800",
            "display": "$580.80"
          },
          "value": {
            "amount": "50.00000000000000000000000000",
            "display": "$50.00"
          }
        },
        {
          "label": "$594.00",
          "at": {
            "amount": "594.00000",
            "display": "$594.00"
          },
          "value": {
            "amount": "62.50000000000000000000000000",
            "display": "$62.50"
          }
        },
        {
          "label": "$607.20",
          "at": {
            "amount": "607.2000",
            "display": "$607.20"
          },
          "value": {
            "amount": "75.00000000000000000000000000",
            "display": "$75.00"
          }
        },
        {
          "label": "$620.40",
          "at": {
            "amount": "620.40000",
            "display": "$620.40"
          },
          "value": {
            "amount": "87.50000000000000000000000000",
            "display": "$87.50"
          }
        },
        {
          "label": "$633.60",
          "at": {
            "amount": "633.600",
            "display": "$633.60"
          },
          "value": {
            "amount": "100.0000000000000000000000000",
            "display": "$100.00"
          }
        },
        {
          "label": "$646.80",
          "at": {
            "amount": "646.80000",
            "display": "$646.80"
          },
          "value": {
            "amount": "112.5000000000000000000000000",
            "display": "$112.50"
          }
        },
        {
          "label": "$660.00",
          "at": {
            "amount": "660.0000",
            "display": "$660.00"
          },
          "value": {
            "amount": "125.0000000000000000000000000",
            "display": "$125.00"
          }
        },
        {
          "label": "$673.20",
          "at": {
            "amount": "673.20000",
            "display": "$673.20"
          },
          "value": {
            "amount": "137.5000000000000000000000000",
            "display": "$137.50"
          }
        },
        {
          "label": "$686.40",
          "at": {
            "amount": "686.400",
            "display": "$686.40"
          },
          "value": {
            "amount": "150.0000000000000000000000000",
            "display": "$150.00"
          }
        }
      ]
    }
  ],
  "annotations": [
    {
      "label": "Entry",
      "text": "$528.00"
    },
    {
      "label": "Break-even",
      "text": "$528.00"
    },
    {
      "label": "Low",
      "text": "at $369.60: -$150.00"
    },
    {
      "label": "High",
      "text": "at $686.40: $150.00"
    }
  ]
}
```

## `portfolio.summary.v1`

> The Home hero: total value, the change over a selected period with its direction, a thirty-day sparkline, the owner's greeting, suggested questions for the assistant and the day's top movers.

- **Frozen id:** `portfolio.summary.v1` · **digest:** `a7389adf90d7`
- **Component:** `PortfolioSummary`
- **Payload type:** `PortfolioSummaryPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `range` | enum 1d / 1w / 1m / ytd / 1y / all | one of '1d', '1w', '1m', 'ytd', '1y', 'all' | `"1d"` | Period the headline change is measured over. `1d` compares to yesterday's close; the others to the portfolio's value that many days back, clamped to the depth of the generated history. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'portfolio.summary.v1' | default `"portfolio.summary.v1"` | `constant` | — | — |
| `greeting` | string ≤24 chars | required | `text` | — | — |
| `account` | object | required | `container` | — | — |
| `account.name` | string ≤64 chars | required | `text` | — | — |
| `account.initial` | string ≤2 chars | required | `text` | — | — |
| `badge` | string ≤32 chars | required | `text` | — | — |
| `total` | object | required | `container` | — | — |
| `total.label` | string ≤64 chars | required | `text` | — | — |
| `total.amount` | object | required | `container` | — | — |
| `total.amount.amount` | decimal | required | `raw` | — | — |
| `total.amount.display` | string ≤32 chars | required | `display` | — | — |
| `change` | object | required | `container` | — | — |
| `change.amount` | object | required | `container` | — | — |
| `change.amount.amount` | decimal | required | `raw` | — | — |
| `change.amount.display` | string ≤32 chars | required | `display` | — | — |
| `change.percent` | object | required | `container` | — | — |
| `change.percent.value` | decimal | required | `raw` | — | — |
| `change.percent.display` | string ≤16 chars | required | `display` | — | — |
| `change.trend` | enum up / down / flat | required | `enum` | variant | — |
| `change.period` | string ≤24 chars | required | `text` | — | — |
| `spark` | array | required | `container` | empty | — |
| `spark[].label` | string ≤16 chars | required | `text` | — | — |
| `spark[].value` | object | required | `container` | — | — |
| `spark[].value.amount` | decimal | required | `raw` | — | — |
| `spark[].value.display` | string ≤32 chars | required | `display` | — | — |
| `questions_title` | string ≤32 chars | required | `text` | — | — |
| `questions` | array | required | `container` | empty | — |
| `questions[].text` | string ≤80 chars | required | `text` | — | — |
| `movers_title` | string ≤32 chars | required | `text` | — | — |
| `movers` | array | required | `container` | empty | — |
| `movers[].symbol` | string ≤10 chars | required | `text` | — | — |
| `movers[].name` | string ≤64 chars | required | `text` | — | — |
| `movers[].price` | object | required | `container` | — | — |
| `movers[].price.amount` | decimal | required | `raw` | — | — |
| `movers[].price.display` | string ≤32 chars | required | `display` | — | — |
| `movers[].change` | object | required | `container` | — | — |
| `movers[].change.value` | decimal | required | `raw` | — | — |
| `movers[].change.display` | string ≤16 chars | required | `display` | — | — |
| `movers[].trend` | enum up / down / flat | required | `enum` | variant | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "portfolio.summary.v1",
  "greeting": "Good afternoon",
  "account": {
    "name": "Alex Chen",
    "initial": "A"
  },
  "badge": "Simulated portfolio",
  "total": {
    "label": "Total portfolio value",
    "amount": {
      "amount": "482915.200000",
      "display": "$482,915.20"
    }
  },
  "change": {
    "amount": {
      "amount": "3240.180000",
      "display": "+$3,240.18"
    },
    "percent": {
      "value": "0.006754948381510465147841136276",
      "display": "+0.68%"
    },
    "trend": "up",
    "period": "today"
  },
  "spark": [
    {
      "label": "12/17/2025",
      "value": {
        "amount": "483925.090000",
        "display": "$483,925.09"
      }
    },
    {
      "label": "12/18/2025",
      "value": {
        "amount": "490455.830000",
        "display": "$490,455.83"
      }
    },
    {
      "label": "12/19/2025",
      "value": {
        "amount": "485749.880000",
        "display": "$485,749.88"
      }
    },
    {
      "label": "12/20/2025",
      "value": {
        "amount": "496136.530000",
        "display": "$496,136.53"
      }
    },
    {
      "label": "12/21/2025",
      "value": {
        "amount": "490383.210000",
        "display": "$490,383.21"
      }
    },
    {
      "label": "12/22/2025",
      "value": {
        "amount": "500360.260000",
        "display": "$500,360.26"
      }
    },
    {
      "label": "12/23/2025",
      "value": {
        "amount": "485722.890000",
        "display": "$485,722.89"
      }
    },
    {
      "label": "12/24/2025",
      "value": {
        "amount": "492370.580000",
        "display": "$492,370.58"
      }
    },
    {
      "label": "12/25/2025",
      "value": {
        "amount": "474144.690000",
        "display": "$474,144.69"
      }
    },
    {
      "label": "12/26/2025",
      "value": {
        "amount": "503941.900000",
        "display": "$503,941.90"
      }
    },
    {
      "label": "12/27/2025",
      "value": {
        "amount": "478867.440000",
        "display": "$478,867.44"
      }
    },
    {
      "label": "12/28/2025",
      "value": {
        "amount": "472092.580000",
        "display": "$472,092.58"
      }
    },
    {
      "label": "12/29/2025",
      "value": {
        "amount": "493866.790000",
        "display": "$493,866.79"
      }
    },
    {
      "label": "12/30/2025",
      "value": {
        "amount": "504498.800000",
        "display": "$504,498.80"
      }
    },
    {
      "label": "12/31/2025",
      "value": {
        "amount": "481439.960000",
        "display": "$481,439.96"
      }
    },
    {
      "label": "01/01/2026",
      "value": {
        "amount": "476545.180000",
        "display": "$476,545.18"
      }
    },
    {
      "label": "01/02/2026",
      "value": {
        "amount": "471818.000000",
        "display": "$471,818.00"
      }
    },
    {
      "label": "01/03/2026",
      "value": {
        "amount": "484773.260000",
        "display": "$484,773.26"
      }
    },
    {
      "label": "01/04/2026",
      "value": {
        "amount": "494319.140000",
        "display": "$494,319.14"
      }
    },
    {
      "label": "01/05/2026",
      "value": {
        "amount": "481487.760000",
        "display": "$481,487.76"
      }
    },
    {
      "label": "01/06/2026",
      "value": {
        "amount": "492346.140000",
        "display": "$492,346.14"
      }
    },
    {
      "label": "01/07/2026",
      "value": {
        "amount": "478818.160000",
        "display": "$478,818.16"
      }
    },
    {
      "label": "01/08/2026",
      "value": {
        "amount": "491936.720000",
        "display": "$491,936.72"
      }
    },
    {
      "label": "01/09/2026",
      "value": {
        "amount": "484251.610000",
        "display": "$484,251.61"
      }
    },
    {
      "label": "01/10/2026",
      "value": {
        "amount": "485292.060000",
        "display": "$485,292.06"
      }
    },
    {
      "label": "01/11/2026",
      "value": {
        "amount": "478052.020000",
        "display": "$478,052.02"
      }
    },
    {
      "label": "01/12/2026",
      "value": {
        "amount": "485748.270000",
        "display": "$485,748.27"
      }
    },
    {
      "label": "01/13/2026",
      "value": {
        "amount": "477916.980000",
        "display": "$477,916.98"
      }
    },
    {
      "label": "01/14/2026",
      "value": {
        "amount": "479675.020000",
        "display": "$479,675.02"
      }
    },
    {
      "label": "01/15/2026",
      "value": {
        "amount": "482915.200000",
        "display": "$482,915.20"
      }
    }
  ],
  "questions_title": "Suggested questions",
  "questions": [
    {
      "text": "What moved my portfolio today?"
    },
    {
      "text": "Tax impact of selling NVDA?"
    },
    {
      "text": "Build a $10k order in tech"
    }
  ],
  "movers_title": "Top movers today",
  "movers": [
    {
      "symbol": "NVDA",
      "name": "NVIDIA Corp",
      "price": {
        "amount": "1204.66",
        "display": "$1,204.66"
      },
      "change": {
        "value": "0.04200328691289680823458178358",
        "display": "+4.2%"
      },
      "trend": "up"
    },
    {
      "symbol": "TSLA",
      "name": "Tesla, Inc.",
      "price": {
        "amount": "298.04",
        "display": "$298.04"
      },
      "change": {
        "value": "-0.02301186651806202058611420704",
        "display": "-2.3%"
      },
      "trend": "down"
    },
    {
      "symbol": "AAPL",
      "name": "Apple Inc.",
      "price": {
        "amount": "233.18",
        "display": "$233.18"
      },
      "change": {
        "value": "0.01101283385362469649670482137",
        "display": "+1.1%"
      },
      "trend": "up"
    }
  ]
}
```

## `scenario.comparison.v1`

> The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method.

- **Frozen id:** `scenario.comparison.v1` · **digest:** `6f73ed9fad79`
- **Component:** `ScenarioComparison`
- **Payload type:** `ScenarioComparisonPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `subject.symbol`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | string ≤10 chars | string matching ^[A-Za-z]{2,10}$, or omit it | `null` | Position to cost the sale against, in any case; omit for the one whose open tax lots are worth the most, ties broken by ticker. |
| `quantity` | decimal | number 0.0..1000000000000.0 or string matching ^(?!^[-+.]*$)[+-]?0*\d*\.?\d{0,8}0*$, or omit it | `null` | Units the sale disposes of; omit for that position's smallest open lot — the smallest sale that still makes the methods differ. |
| `methods` | array ≤3 items | list of up to 3 (an unrecognised shape — do not guess) | `["FIFO", "LIFO", "HIFO"]` | Lot-selection methods to compare, in the order they are shown. At least two, all distinct — two identical columns would claim a difference that does not exist. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'scenario.comparison.v1' | default `"scenario.comparison.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `subject` | object | required | `container` | — | — |
| `subject.label` | string ≤64 chars | required | `text` | — | — |
| `subject.symbol` | string | required | `text` | — | input · string matching ^[A-Za-z]{2,10}$, or omit it |
| `subject.quantity_display` | string ≤32 chars | required | `text` | — | — |
| `subject.price` | object | required | `container` | — | — |
| `subject.price.amount` | decimal | required | `raw` | — | — |
| `subject.price.display` | string ≤32 chars | required | `display` | — | — |
| `subject.proceeds` | object | required | `container` | — | — |
| `subject.proceeds.amount` | decimal | required | `raw` | — | — |
| `subject.proceeds.display` | string ≤32 chars | required | `display` | — | — |
| `columns` | array | required | `container` | empty | — |
| `columns[].method` | enum FIFO / LIFO / HIFO | required | `enum` | variant | — |
| `columns[].label` | string ≤64 chars | required | `text` | — | — |
| `columns[].cost_basis` | object | required | `container` | — | — |
| `columns[].cost_basis.amount` | decimal | required | `raw` | — | — |
| `columns[].cost_basis.display` | string ≤32 chars | required | `display` | — | — |
| `columns[].realized_pl` | object | required | `container` | — | — |
| `columns[].realized_pl.amount` | decimal | required | `raw` | — | — |
| `columns[].realized_pl.display` | string ≤32 chars | required | `display` | — | — |
| `columns[].short_term_pl` | object | required | `container` | — | — |
| `columns[].short_term_pl.amount` | decimal | required | `raw` | — | — |
| `columns[].short_term_pl.display` | string ≤32 chars | required | `display` | — | — |
| `columns[].long_term_pl` | object | required | `container` | — | — |
| `columns[].long_term_pl.amount` | decimal | required | `raw` | — | — |
| `columns[].long_term_pl.display` | string ≤32 chars | required | `display` | — | — |
| `columns[].short_term_lots` | integer 0..None | required | `raw` | — | — |
| `columns[].long_term_lots` | integer 0..None | required | `raw` | — | — |
| `columns[].lots` | array | required | `container` | empty | — |
| `spread` | object | required | `container` | — | — |
| `spread.amount` | object | required | `container` | — | — |
| `spread.amount.amount` | decimal | required | `raw` | — | — |
| `spread.amount.display` | string ≤32 chars | required | `display` | — | — |
| `spread.differs` | boolean | required | `flag` | variant | — |
| `spread.highest` | object | default `null` | `text` | null | — |
| `spread.lowest` | object | default `null` | `text` | null | — |
| `notes` | array | default `[]` | `container` | empty | — |
| `notes[].label` | string ≤64 chars | required | `text` | — | — |
| `notes[].text` | string ≤200 chars | required | `text` | — | — |

### When the agent picks this

- **Use it when** the user faces a choice between strategies and the decision hinges on comparing the same metrics across them — which lots to sell, selling now or waiting. Every column's figures come from this render; never fabricate the comparison.
- **Do not use it for** a single option, where there is nothing to compare — `taxlots.table.v1` shows one sale in detail. Do not rank or bold the values in prose: this card names the spread and recommends no method.

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "scenario.comparison.v1",
  "title": "Same sale, different lot method",
  "subject": {
    "label": "NVIDIA Corp",
    "symbol": "NVDA",
    "quantity_display": "30",
    "price": {
      "amount": "1204.66",
      "display": "$1,204.66"
    },
    "proceeds": {
      "amount": "36139.800000",
      "display": "$36,139.80"
    }
  },
  "columns": [
    {
      "method": "FIFO",
      "label": "FIFO \u2014 oldest lots first",
      "cost_basis": {
        "amount": "22800.00",
        "display": "$22,800.00"
      },
      "realized_pl": {
        "amount": "13339.800000",
        "display": "+$13,339.80"
      },
      "short_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "long_term_pl": {
        "amount": "13339.800000",
        "display": "+$13,339.80"
      },
      "short_term_lots": 0,
      "long_term_lots": 1,
      "lots": [
        "lot-nvda-01"
      ]
    },
    {
      "method": "LIFO",
      "label": "LIFO \u2014 newest lots first",
      "cost_basis": {
        "amount": "28800.00",
        "display": "$28,800.00"
      },
      "realized_pl": {
        "amount": "7339.800000",
        "display": "+$7,339.80"
      },
      "short_term_pl": {
        "amount": "7339.800000",
        "display": "+$7,339.80"
      },
      "long_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "short_term_lots": 1,
      "long_term_lots": 0,
      "lots": [
        "lot-nvda-02"
      ]
    },
    {
      "method": "HIFO",
      "label": "HIFO \u2014 dearest lots first",
      "cost_basis": {
        "amount": "28800.00",
        "display": "$28,800.00"
      },
      "realized_pl": {
        "amount": "7339.800000",
        "display": "+$7,339.80"
      },
      "short_term_pl": {
        "amount": "7339.800000",
        "display": "+$7,339.80"
      },
      "long_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "short_term_lots": 1,
      "long_term_lots": 0,
      "lots": [
        "lot-nvda-02"
      ]
    }
  ],
  "spread": {
    "amount": {
      "amount": "6000.000000",
      "display": "$6,000.00"
    },
    "differs": true,
    "highest": "FIFO",
    "lowest": "LIFO"
  },
  "notes": [
    {
      "label": "Before tax",
      "text": "The realised result and its short/long split, before any tax rate, fee or wash-sale rule."
    },
    {
      "label": "Not advice",
      "text": "No method is recommended: which result is preferable depends on a tax situation this demo does not know."
    }
  ]
}
```

## `taxlots.table.v1`

> Tax-lot table for a proposed sale: the lots it consumes under FIFO, LIFO or HIFO, each with its holding period, and the realised result split short-term vs long-term. Nothing is traded.

- **Frozen id:** `taxlots.table.v1` · **digest:** `c960b55bd552`
- **Component:** `TaxLotTable`
- **Payload type:** `TaxLotsTablePayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `fields` | array ≤8 items | list of up to 8 (text), or omit it | `null` | Sections to render; omit for all of them. A section this view does not offer is rejected, never ignored. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | string ≤10 chars | string matching ^[A-Za-z]{2,10}$ | `"NVDA"` | Ticker being sold, in any case. |
| `quantity` | string | string matching ^\d{1,12}(\.\d{1,8})?$ | `"75"` | Units to sell, written as a decimal string ('0.5'). A dollar-sized ask is resolved to units by the `simulate_sale` tool; copy the units it returned rather than dividing (spec 0015 OD-4). |
| `lot_method` | enum FIFO / LIFO / HIFO | one of 'FIFO', 'LIFO', 'HIFO' | `"FIFO"` | Which lots the sale consumes first: FIFO the oldest, LIFO the newest, HIFO the dearest. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'taxlots.table.v1' | default `"taxlots.table.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `subtitle` | string ≤200 chars | required | `text` | — | — |
| `proceeds` | object | required | `container` | — | — |
| `proceeds.label` | string ≤64 chars | required | `text` | — | — |
| `proceeds.amount` | object | required | `container` | — | — |
| `proceeds.amount.amount` | decimal | required | `raw` | — | — |
| `proceeds.amount.display` | string ≤32 chars | required | `display` | — | — |
| `cost_basis` | object | required | `container` | — | — |
| `cost_basis.label` | string ≤64 chars | required | `text` | — | — |
| `cost_basis.amount` | object | required | `container` | — | — |
| `cost_basis.amount.amount` | decimal | required | `raw` | — | — |
| `cost_basis.amount.display` | string ≤32 chars | required | `display` | — | — |
| `realized` | object | required | `container` | — | — |
| `realized.label` | string ≤64 chars | required | `text` | — | — |
| `realized.amount` | object | required | `container` | — | — |
| `realized.amount.amount` | decimal | required | `raw` | — | — |
| `realized.amount.display` | string ≤32 chars | required | `display` | — | — |
| `by_term` | array | required | `container` | empty | — |
| `by_term[].label` | string ≤64 chars | required | `text` | — | — |
| `by_term[].term` | enum short / long | required | `enum` | variant | — |
| `by_term[].lots` | integer 0..None | required | `raw` | — | — |
| `by_term[].realized` | object | required | `container` | — | — |
| `by_term[].realized.amount` | decimal | required | `raw` | — | — |
| `by_term[].realized.display` | string ≤32 chars | required | `display` | — | — |
| `lots` | array | default `[]` | `container` | empty | — |
| `lots[].label` | string ≤64 chars | required | `text` | — | — |
| `lots[].acquired_on` | string | required | `text` | — | — |
| `lots[].acquired_on_display` | string ≤32 chars | required | `text` | — | — |
| `lots[].term` | enum short / long | required | `enum` | variant | — |
| `lots[].units` | decimal | required | `raw` | — | — |
| `lots[].units_display` | string ≤32 chars | required | `text` | — | — |
| `lots[].cost_basis` | object | required | `container` | — | — |
| `lots[].cost_basis.amount` | decimal | required | `raw` | — | — |
| `lots[].cost_basis.display` | string ≤32 chars | required | `display` | — | — |
| `lots[].proceeds` | object | required | `container` | — | — |
| `lots[].proceeds.amount` | decimal | required | `raw` | — | — |
| `lots[].proceeds.display` | string ≤32 chars | required | `display` | — | — |
| `lots[].gain_loss` | object | required | `container` | — | — |
| `lots[].gain_loss.amount` | decimal | required | `raw` | — | — |
| `lots[].gain_loss.display` | string ≤32 chars | required | `display` | — | — |
| `lots[].trend` | string ≤8 chars | required | `text` | — | — |
| `lots[].fully_sold` | boolean | required | `flag` | variant | — |

### When the agent picks this

- **Use it when** the user asks about selling a position and the answer depends on WHICH lots go — the realised result always splits into its short-term and long-term halves, which is the point of the surface.
- **Do not use it for** comparing several lot-selection methods — `scenario.comparison.v1` puts those side by side. Never estimate a tax rate in prose: this view stops at the realised split, before any rate, fee or wash sale.

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "taxlots.table.v1",
  "title": "Tax lots this sale consumes",
  "subtitle": "Sell 75 NVDA under FIFO",
  "proceeds": {
    "label": "Proceeds",
    "amount": {
      "amount": "90349.500000",
      "display": "$90,349.50"
    }
  },
  "cost_basis": {
    "label": "Cost basis",
    "amount": {
      "amount": "60000.00",
      "display": "$60,000.00"
    }
  },
  "realized": {
    "label": "Realised P/L",
    "amount": {
      "amount": "30349.500000",
      "display": "+$30,349.50"
    }
  },
  "by_term": [
    {
      "label": "Short-term",
      "term": "short",
      "lots": 1,
      "realized": {
        "amount": "3669.900000",
        "display": "+$3,669.90"
      }
    },
    {
      "label": "Long-term",
      "term": "long",
      "lots": 1,
      "realized": {
        "amount": "26679.600000",
        "display": "+$26,679.60"
      }
    }
  ],
  "lots": [
    {
      "label": "lot-nvda-01",
      "acquired_on": "2025-01-13",
      "acquired_on_display": "01/13/2025",
      "term": "long",
      "units": "60.0000",
      "units_display": "60",
      "cost_basis": {
        "amount": "45600.00",
        "display": "$45,600.00"
      },
      "proceeds": {
        "amount": "72279.600000",
        "display": "$72,279.60"
      },
      "gain_loss": {
        "amount": "26679.600000",
        "display": "+$26,679.60"
      },
      "trend": "up",
      "fully_sold": true
    },
    {
      "label": "lot-nvda-02",
      "acquired_on": "2025-01-17",
      "acquired_on_display": "01/17/2025",
      "term": "short",
      "units": "15.0000",
      "units_display": "15",
      "cost_basis": {
        "amount": "14400.00",
        "display": "$14,400.00"
      },
      "proceeds": {
        "amount": "18069.900000",
        "display": "$18,069.90"
      },
      "gain_loss": {
        "amount": "3669.900000",
        "display": "+$3,669.90"
      },
      "trend": "up",
      "fully_sold": false
    }
  ]
}
```
