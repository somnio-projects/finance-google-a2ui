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
| [`activity.timeline.v1`](#activitytimelinev1) | `ActivityTimeline` | `ca94f0c3c8bf` | 23 | `kind`, `query`, `groups[].entries[].kind` | The Activity tab: the ledger as a timeline grouped under today, this week and each month, filtered by kind, every row captioned and its amount signed the way the design colours it. |
| [`attribution.driver.v1`](#attributiondriverv1) | `DriverDetail` | `aa0536008605` | 35 | `symbol` | One holding's part in today's move: its contribution, the price move behind it, the units that carried it and its share of the day's result. The card a tapped waterfall bar opens. |
| [`attribution.waterfall.v1`](#attributionwaterfallv1) | `AttributionWaterfall` | `d33d3882383f` | 52 | read-only | Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first. |
| [`attribution.window.v1`](#attributionwindowv1) | `AttributionWaterfall` | `abde9901e9d2` | 47 | `window` | The portfolio's move over a chosen window, one bucket per holding, biggest mover first. Not unrealised profit and loss: this compares each holding to what it was worth when the window opened, not to what it cost. |
| [`holdings.allocation.v1`](#holdingsallocationv1) | `HoldingsSummary` | `cc5bbfb7061b` | 25 | `group_by` | Allocation of the portfolio's market value — by holding, asset class or sector — with weight and day change per slice, the count in the donut's centre, and the all-time gain under the total. |
| [`holdings.positions.v1`](#holdingspositionsv1) | `PositionList` | `9ff39ae83d7f` | 44 | `asset_class`, `query` | The Holdings tab: total value with the all-time gain, then one row per position — units and average cost, value, unrealised result, today's move, price and weight — each with the question that hands it to the assistant. |
| [`order.ticket.v1`](#orderticketv1) | `OrderTicket` | `4f00c29a4c39` | 28 | `symbol`, `side`, `size`, `size_in` | Order ticket: a proposed buy or sell with its units, entry price and notional, plus the bounded inputs that re-render it. It places nothing. |
| [`order.ticket.v2`](#orderticketv2) | `MultiLegOrderTicket` | `8cd79663e799` | 59 | `side`, `legs` | Multi-leg draft order: each leg struck at its reference price with its weight in the order, the order's impact — total, fees, cash remaining, the group's weight before and after — and whether the available cash covers it. Editing a leg re-renders it; it places nothing. |
| [`payoff.curve.v1`](#payoffcurvev1) | `RiskPayoffChart` | `922cd5dac6f0` | 32 | read-only | Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff. |
| [`portfolio.summary.v1`](#portfoliosummaryv1) | `PortfolioSummary` | `191db33e1a5f` | 39 | read-only | The Home hero: total value, the change over a selected period with its direction, a thirty-day sparkline, the owner's greeting, suggested questions for the assistant and the day's top movers. |
| [`scenario.comparison.v1`](#scenariocomparisonv1) | `ScenarioComparison` | `f3cae9fd15c1` | 40 | `subject.symbol` | The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method. |
| [`taxlots.table.v1`](#taxlotstablev1) | `TaxLotTable` | `0556567d7b94` | 45 | read-only | Tax-lot table for a proposed sale: the lots it consumes under FIFO, LIFO or HIFO, each with its holding period, and the realised result split short-term vs long-term. Nothing is traded. |

## `activity.timeline.v1`

> The Activity tab: the ledger as a timeline grouped under today, this week and each month, filtered by kind, every row captioned and its amount signed the way the design colours it.

- **Frozen id:** `activity.timeline.v1` · **digest:** `ca94f0c3c8bf`
- **Component:** `ActivityTimeline`
- **Payload type:** `ActivityTimelinePayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `kind`, `query`, `groups[].entries[].kind`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `query` | string ≤24 chars | string of up to 24 characters, or omit it | `null` | Narrow the rows to those whose symbol or description contains this text, case-insensitively. Blank or omitted is no filter. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `kind` | enum all / buy / sell / staking_reward / deposit | one of 'all', 'buy', 'sell', 'staking_reward', 'deposit' | `"all"` | Which rows to show. |
| `limit` | integer 1..200 | integer 1..200 | `100` | Newest rows kept. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'activity.timeline.v1' | default `"activity.timeline.v1"` | `constant` | — | — |
| `title` | string ≤32 chars | default `"Activity"` | `text` | — | — |
| `note` | string ≤64 chars | default `"Simulated activity \u2014 resets each session."` | `text` | — | — |
| `kind` | enum all / buy / sell / staking_reward / deposit | required | `enum` | variant | input · one of 'all', 'buy', 'sell', 'staking_reward', 'deposit' |
| `query` | string ≤24 chars | default `null` | `text` | null | input · string of up to 24 characters, or omit it |
| `filters` | array ≤8 items | default `[{"key": "all", "label": "All"}, {"key": "buy", "label": "Buys"}, {"key": "sell", "label": "Sells"}, {"key": "staking_reward", "label": "Staking"}, {"key": "deposit", "label": "Deposits"}]` | `container` | empty | — |
| `filters[].key` | enum all / buy / sell / staking_reward / deposit | required | `enum` | variant | — |
| `filters[].label` | string ≤16 chars | required | `text` | — | — |
| `empty` | string ≤48 chars | default `"No activity matches this filter."` | `text` | — | — |
| `groups` | array ≤64 items | required | `container` | empty | — |
| `groups[].label` | string ≤24 chars | required | `text` | — | — |
| `groups[].entries` | array ≤200 items | required | `container` | empty | — |
| `groups[].entries[].key` | string ≤32 chars | required | `text` | — | — |
| `groups[].entries[].kind` | enum buy / sell / staking_reward / deposit | required | `enum` | variant | input · one of 'all', 'buy', 'sell', 'staking_reward', 'deposit' |
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
  "query": null,
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
      "key": "staking_reward",
      "label": "Staking"
    },
    {
      "key": "deposit",
      "label": "Deposits"
    }
  ],
  "empty": "No activity matches this filter.",
  "groups": [
    {
      "label": "TODAY",
      "entries": [
        {
          "key": "txn-0017",
          "kind": "staking_reward",
          "title": "Staking \u2014 ETH",
          "detail": "$3,480.00/unit \u00b7 0.075 units \u00b7 protocol reward",
          "amount": {
            "amount": "261.00",
            "display": "+$261.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "THIS WEEK",
      "entries": [
        {
          "key": "txn-0033",
          "kind": "deposit",
          "title": "Deposit \u2014 Transfer in",
          "detail": "Coinbase \u2022\u20224021 \u00b7 Tue",
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
          "key": "txn-0018",
          "kind": "staking_reward",
          "title": "Staking \u2014 SOL",
          "detail": "$152.40/unit \u00b7 2.2 units \u00b7 protocol reward",
          "amount": {
            "amount": "335.28",
            "display": "+$335.28"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0019",
          "kind": "staking_reward",
          "title": "Staking \u2014 LINK",
          "detail": "$22.60/unit \u00b7 12 units \u00b7 protocol reward",
          "amount": {
            "amount": "271.20",
            "display": "+$271.20"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0034",
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
          "key": "txn-0016",
          "kind": "sell",
          "title": "Sold 900 AVAX",
          "detail": "900 units @ $52.00 \u00b7 Dec 26",
          "amount": {
            "amount": "46800.00",
            "display": "$46,800.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "19800.0000000000",
              "display": "+$19,800"
            },
            "text": "+$19,800 realized",
            "trend": "up"
          },
          "term": {
            "term": "short",
            "label": "ST gain"
          }
        },
        {
          "key": "txn-0020",
          "kind": "staking_reward",
          "title": "Staking \u2014 AAVE",
          "detail": "$248.00/unit \u00b7 0.5 units \u00b7 protocol reward",
          "amount": {
            "amount": "124.00",
            "display": "+$124.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0021",
          "kind": "staking_reward",
          "title": "Staking \u2014 ETH",
          "detail": "$3,400.00/unit \u00b7 0.075 units \u00b7 protocol reward",
          "amount": {
            "amount": "255.00",
            "display": "+$255.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0035",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Dec 2",
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
      "label": "NOVEMBER 2025",
      "entries": [
        {
          "key": "txn-0022",
          "kind": "staking_reward",
          "title": "Staking \u2014 SOL",
          "detail": "$148.00/unit \u00b7 2.2 units \u00b7 protocol reward",
          "amount": {
            "amount": "325.60",
            "display": "+$325.60"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0015",
          "kind": "sell",
          "title": "Sold 0.25 BTC",
          "detail": "0.25 units @ $58,400.00 \u00b7 Nov 16",
          "amount": {
            "amount": "14600.00",
            "display": "$14,600.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "5600.0000000000",
              "display": "+$5,600"
            },
            "text": "+$5,600 realized",
            "trend": "up"
          },
          "term": {
            "term": "short",
            "label": "ST gain"
          }
        },
        {
          "key": "txn-0023",
          "kind": "staking_reward",
          "title": "Staking \u2014 LINK",
          "detail": "$21.50/unit \u00b7 12 units \u00b7 protocol reward",
          "amount": {
            "amount": "258.00",
            "display": "+$258.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0036",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Nov 2",
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
      "label": "OCTOBER 2025",
      "entries": [
        {
          "key": "txn-0024",
          "kind": "staking_reward",
          "title": "Staking \u2014 AAVE",
          "detail": "$232.00/unit \u00b7 0.5 units \u00b7 protocol reward",
          "amount": {
            "amount": "116.00",
            "display": "+$116.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0025",
          "kind": "staking_reward",
          "title": "Staking \u2014 ETH",
          "detail": "$3,280.00/unit \u00b7 0.075 units \u00b7 protocol reward",
          "amount": {
            "amount": "246.00",
            "display": "+$246.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0014",
          "kind": "sell",
          "title": "Sold 400 LINK",
          "detail": "400 units @ $19.80 \u00b7 Oct 12",
          "amount": {
            "amount": "7920.00",
            "display": "$7,920.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "-2420.0000000000",
              "display": "-$2,420"
            },
            "text": "-$2,420 realized",
            "trend": "down"
          },
          "term": {
            "term": "short",
            "label": "ST loss"
          }
        },
        {
          "key": "txn-0037",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Oct 3",
          "amount": {
            "amount": "2500.00",
            "display": "+$2,500.00"
          },
          "tone": "up",
          "badge": "Deposit",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0026",
          "kind": "staking_reward",
          "title": "Staking \u2014 SOL",
          "detail": "$160.00/unit \u00b7 2.2 units \u00b7 protocol reward",
          "amount": {
            "amount": "352.00",
            "display": "+$352.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "SEPTEMBER 2025",
      "entries": [
        {
          "key": "txn-0013",
          "kind": "sell",
          "title": "Sold 60 SOL",
          "detail": "60 units @ $145.00 \u00b7 Sep 17",
          "amount": {
            "amount": "8700.00",
            "display": "$8,700.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "-1962.0000000000",
              "display": "-$1,962"
            },
            "text": "-$1,962 realized",
            "trend": "down"
          },
          "term": {
            "term": "long",
            "label": "LT loss"
          }
        },
        {
          "key": "txn-0027",
          "kind": "staking_reward",
          "title": "Staking \u2014 LINK",
          "detail": "$24.00/unit \u00b7 12 units \u00b7 protocol reward",
          "amount": {
            "amount": "288.00",
            "display": "+$288.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0038",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Sep 3",
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
      "label": "AUGUST 2025",
      "entries": [
        {
          "key": "txn-0028",
          "kind": "staking_reward",
          "title": "Staking \u2014 AVAX",
          "detail": "$45.00/unit \u00b7 6 units \u00b7 protocol reward",
          "amount": {
            "amount": "270.00",
            "display": "+$270.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0029",
          "kind": "staking_reward",
          "title": "Staking \u2014 ETH",
          "detail": "$3,120.00/unit \u00b7 0.075 units \u00b7 protocol reward",
          "amount": {
            "amount": "234.00",
            "display": "+$234.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0039",
          "kind": "deposit",
          "title": "Deposit \u2014 Transfer in",
          "detail": "Kraken \u2022\u20227788 \u00b7 Aug 3",
          "amount": {
            "amount": "3200.00",
            "display": "+$3,200.00"
          },
          "tone": "up",
          "badge": "Deposit",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "JULY 2025",
      "entries": [
        {
          "key": "txn-0012",
          "kind": "sell",
          "title": "Sold 25 AAVE",
          "detail": "25 units @ $150.00 \u00b7 Jul 31",
          "amount": {
            "amount": "3750.00",
            "display": "$3,750.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "-735.0000000000",
              "display": "-$735"
            },
            "text": "-$735 realized",
            "trend": "down"
          },
          "term": {
            "term": "long",
            "label": "LT loss"
          }
        },
        {
          "key": "txn-0030",
          "kind": "staking_reward",
          "title": "Staking \u2014 SOL",
          "detail": "$138.00/unit \u00b7 2.2 units \u00b7 protocol reward",
          "amount": {
            "amount": "303.60",
            "display": "+$303.60"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0031",
          "kind": "staking_reward",
          "title": "Staking \u2014 AVAX",
          "detail": "$38.50/unit \u00b7 6 units \u00b7 protocol reward",
          "amount": {
            "amount": "231.00",
            "display": "+$231.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0040",
          "kind": "deposit",
          "title": "Deposit \u2014 Payroll",
          "detail": "Recurring \u00b7 Jul 4",
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
      "label": "JUNE 2025",
      "entries": [
        {
          "key": "txn-0011",
          "kind": "sell",
          "title": "Sold 2.5 ETH",
          "detail": "2.5 units @ $3,150.00 \u00b7 Jun 19",
          "amount": {
            "amount": "7875.00",
            "display": "$7,875.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "3250.0000000000",
              "display": "+$3,250"
            },
            "text": "+$3,250 realized",
            "trend": "up"
          },
          "term": {
            "term": "long",
            "label": "LT gain"
          }
        },
        {
          "key": "txn-0032",
          "kind": "staking_reward",
          "title": "Staking \u2014 LINK",
          "detail": "$26.00/unit \u00b7 12 units \u00b7 protocol reward",
          "amount": {
            "amount": "312.00",
            "display": "+$312.00"
          },
          "tone": "up",
          "badge": "Staking",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "MAY 2025",
      "entries": [
        {
          "key": "txn-0041",
          "kind": "deposit",
          "title": "Deposit \u2014 Bonus",
          "detail": "Annual \u00b7 May 20",
          "amount": {
            "amount": "7500.00",
            "display": "+$7,500.00"
          },
          "tone": "up",
          "badge": "Deposit",
          "realized": null,
          "term": null
        }
      ]
    },
    {
      "label": "MARCH 2025",
      "entries": [
        {
          "key": "txn-0009",
          "kind": "buy",
          "title": "Bought 12 ETH",
          "detail": "12 units @ $4,175.00 \u00b7 Mar 21",
          "amount": {
            "amount": "-50100.00",
            "display": "-$50,100.00"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0010",
          "kind": "sell",
          "title": "Sold 8000 ARB",
          "detail": "8000 units @ $1.24 \u00b7 Mar 21",
          "amount": {
            "amount": "9920.00",
            "display": "$9,920.00"
          },
          "tone": "flat",
          "badge": "Sell",
          "realized": {
            "amount": {
              "amount": "2560.000000000000",
              "display": "+$2,560"
            },
            "text": "+$2,560 realized",
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
      "label": "FEBRUARY 2025",
      "entries": [
        {
          "key": "txn-0008",
          "kind": "buy",
          "title": "Bought 900 AVAX",
          "detail": "900 units @ $30.00 \u00b7 Feb 19",
          "amount": {
            "amount": "-27000.00",
            "display": "-$27,000.00"
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
          "key": "txn-0007",
          "kind": "buy",
          "title": "Bought 1.85 BTC",
          "detail": "1.85 units @ $42,468.00 \u00b7 Jan 17",
          "amount": {
            "amount": "-78565.80",
            "display": "-$78,565.80"
          },
          "tone": "flat",
          "badge": "Buy",
          "realized": null,
          "term": null
        },
        {
          "key": "txn-0006",
          "kind": "buy",
          "title": "Bought 0.5 BTC",
          "detail": "0.5 units @ $36,000.00 \u00b7 Jan 13",
          "amount": {
            "amount": "-18000.00",
            "display": "-$18,000.00"
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
          "key": "txn-0005",
          "kind": "buy",
          "title": "Bought 2500 LINK",
          "detail": "2500 units @ $25.85 \u00b7 Nov 11",
          "amount": {
            "amount": "-64625.00",
            "display": "-$64,625.00"
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
          "key": "txn-0004",
          "kind": "buy",
          "title": "Bought 58625 ARB",
          "detail": "58625 units @ $0.92 \u00b7 Sep 22",
          "amount": {
            "amount": "-53935.00",
            "display": "-$53,935.00"
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
          "key": "txn-0003",
          "kind": "buy",
          "title": "Bought 435.5 SOL",
          "detail": "435.5 units @ $177.70 \u00b7 Jul 24",
          "amount": {
            "amount": "-77388.35",
            "display": "-$77,388.35"
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
          "key": "txn-0002",
          "kind": "buy",
          "title": "Bought 200 AAVE",
          "detail": "200 units @ $179.40 \u00b7 May 15",
          "amount": {
            "amount": "-35880.00",
            "display": "-$35,880.00"
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
          "title": "Bought 20.5 ETH",
          "detail": "20.5 units @ $1,850.00 \u00b7 Nov 7",
          "amount": {
            "amount": "-37925.00",
            "display": "-$37,925.00"
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

## `attribution.driver.v1`

> One holding's part in today's move: its contribution, the price move behind it, the units that carried it and its share of the day's result. The card a tapped waterfall bar opens.

- **Frozen id:** `attribution.driver.v1` · **digest:** `aa0536008605`
- **Component:** `DriverDetail`
- **Payload type:** `DriverDetailPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `symbol`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | enum AAVE / ARB / AVAX / BTC / ETH / LINK / SOL / USDC | one of 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' | `"BTC"` | The holding to describe, from the market reference. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'attribution.driver.v1' | default `"attribution.driver.v1"` | `constant` | — | — |
| `symbol` | string ≤10 chars | required | `text` | — | input · one of 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' |
| `name` | string ≤64 chars | required | `text` | — | — |
| `caption` | string ≤48 chars | required | `text` | — | — |
| `contribution` | object | required | `container` | — | — |
| `contribution.amount` | decimal | required | `raw` | — | — |
| `contribution.display` | string ≤32 chars | required | `display` | — | — |
| `trend` | enum up / down / flat | required | `enum` | variant | — |
| `price_move` | object | required | `container` | — | — |
| `price_move.label` | string ≤64 chars | required | `text` | — | — |
| `price_move.percent` | object | required | `container` | — | — |
| `price_move.percent.value` | decimal | required | `raw` | — | — |
| `price_move.percent.display` | string ≤16 chars | required | `display` | — | — |
| `price_move.amount` | object | required | `container` | — | — |
| `price_move.amount.amount` | decimal | required | `raw` | — | — |
| `price_move.amount.display` | string ≤32 chars | required | `display` | — | — |
| `price_move.trend` | enum up / down / flat | required | `enum` | variant | — |
| `holding` | object | required | `container` | — | — |
| `holding.label` | string ≤64 chars | required | `text` | — | — |
| `holding.units` | object | required | `container` | — | — |
| `holding.units.units` | decimal | required | `raw` | — | — |
| `holding.units.display` | string ≤32 chars | required | `display` | — | — |
| `holding.price` | object | required | `container` | — | — |
| `holding.price.amount` | decimal | required | `raw` | — | — |
| `holding.price.display` | string ≤32 chars | required | `display` | — | — |
| `holding.caption` | string ≤40 chars | required | `text` | — | — |
| `day_share` | object | required | `container` | — | — |
| `day_share.label` | string ≤64 chars | required | `text` | — | — |
| `day_share.percent` | object | required | `container` | — | — |
| `day_share.percent.value` | decimal | required | `raw` | — | — |
| `day_share.percent.display` | string ≤16 chars | required | `display` | — | — |
| `day_share.total` | object | required | `container` | — | — |
| `day_share.total.amount` | decimal | required | `raw` | — | — |
| `day_share.total.display` | string ≤32 chars | required | `display` | — | — |
| `day_share.caption` | string ≤40 chars | required | `text` | — | — |

### When the agent picks this

_No design page for this component yet, so the catalog teaches the model only this view's summary and its options. It is not guidance this backend may invent._

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "attribution.driver.v1",
  "symbol": "BTC",
  "name": "Bitcoin",
  "caption": "Top contributor today",
  "contribution": {
    "amount": "4767.0000000000",
    "display": "+$4,767.00"
  },
  "trend": "up",
  "price_move": {
    "label": "Price move",
    "percent": {
      "value": "0.03662471765085511455308163924",
      "display": "+3.66%"
    },
    "amount": {
      "amount": "2270.00",
      "display": "+$2,270.00"
    },
    "trend": "up"
  },
  "holding": {
    "label": "BTC held",
    "units": {
      "units": "2.10000000",
      "display": "2.1"
    },
    "price": {
      "amount": "64250.00",
      "display": "$64,250.00"
    },
    "caption": "@ $64,250.00"
  },
  "day_share": {
    "label": "Of day gain",
    "percent": {
      "value": "2.165784511937484382453828854",
      "display": "216.58%"
    },
    "total": {
      "amount": "2201.050000000000",
      "display": "+$2,201.05"
    },
    "caption": "of +$2,201.05"
  }
}
```

## `attribution.waterfall.v1`

> Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first.

- **Frozen id:** `attribution.waterfall.v1` · **digest:** `d33d3882383f`
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
| `net` | object | required | `container` | — | — |
| `net.label` | string ≤64 chars | required | `text` | — | — |
| `net.amount` | object | required | `container` | — | — |
| `net.amount.amount` | decimal | required | `raw` | — | — |
| `net.amount.display` | string ≤32 chars | required | `display` | — | — |
| `net.percent` | object | required | `container` | — | — |
| `net.percent.value` | decimal | required | `raw` | — | — |
| `net.percent.display` | string ≤16 chars | required | `display` | — | — |
| `net.direction` | enum up / down / flat | required | `enum` | variant | — |
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
| `buckets[].move` | object | required | `container` | — | — |
| `buckets[].move.value` | decimal | required | `raw` | — | — |
| `buckets[].move.display` | string ≤16 chars | required | `display` | — | — |
| `buckets[].units` | object | required | `container` | — | — |
| `buckets[].units.units` | decimal | required | `raw` | — | — |
| `buckets[].units.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].price` | object | required | `container` | — | — |
| `buckets[].price.amount` | decimal | required | `raw` | — | — |
| `buckets[].price.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].detail` | string ≤64 chars | required | `text` | — | — |
| `buckets[].delta_label` | string ≤32 chars | required | `text` | — | — |
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
| `drill.attribution.v1` | Break this down | `driver` | choice | 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' |

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
      "amount": "482915.200000000000",
      "display": "$482,915.20"
    }
  },
  "net": {
    "label": "Net",
    "amount": {
      "amount": "61204.050000000000",
      "display": "+$61,204.05"
    },
    "percent": {
      "value": "0.1451326340316114477883736297",
      "display": "+14.51%"
    },
    "direction": "up"
  },
  "buckets": [
    {
      "label": "Bitcoin",
      "key": "BTC",
      "delta": {
        "amount": "47359.2000000000",
        "display": "$47,359.20"
      },
      "cumulative": {
        "amount": "469070.3500000000",
        "display": "$469,070.35"
      },
      "direction": "up",
      "move": {
        "value": "0.5408412873519113626552832270",
        "display": "+54.08%"
      },
      "units": {
        "units": "2.10000000",
        "display": "2.1"
      },
      "price": {
        "amount": "64250.00",
        "display": "$64,250.00"
      },
      "detail": "+54.08% \u00b7 2.1 BTC \u00b7 $64,250.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Ethereum",
      "key": "ETH",
      "delta": {
        "amount": "21000.0000000000",
        "display": "$21,000.00"
      },
      "cumulative": {
        "amount": "490070.3500000000",
        "display": "$490,070.35"
      },
      "direction": "up",
      "move": {
        "value": "0.2517985611510791366906474820",
        "display": "+25.18%"
      },
      "units": {
        "units": "30.00000000",
        "display": "30"
      },
      "price": {
        "amount": "3480.00",
        "display": "$3,480.00"
      },
      "detail": "+25.18% \u00b7 30 ETH \u00b7 $3,480.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Aave",
      "key": "AAVE",
      "delta": {
        "amount": "12005.0000000000",
        "display": "$12,005.00"
      },
      "cumulative": {
        "amount": "502075.3500000000",
        "display": "$502,075.35"
      },
      "direction": "up",
      "move": {
        "value": "0.3823857302118171683389074693",
        "display": "+38.24%"
      },
      "units": {
        "units": "175.00000000",
        "display": "175"
      },
      "price": {
        "amount": "248.00",
        "display": "$248.00"
      },
      "detail": "+38.24% \u00b7 175 AAVE \u00b7 $248.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Solana",
      "key": "SOL",
      "delta": {
        "amount": "-9500.1500000000",
        "display": "-$9,500.15"
      },
      "cumulative": {
        "amount": "492575.2000000000",
        "display": "$492,575.20"
      },
      "direction": "down",
      "move": {
        "value": "-0.1423747889701744513224535734",
        "display": "-14.24%"
      },
      "units": {
        "units": "375.50000000",
        "display": "375.5"
      },
      "price": {
        "amount": "152.40",
        "display": "$152.40"
      },
      "detail": "-14.24% \u00b7 375.5 SOL \u00b7 $152.40",
      "delta_label": "Contribution"
    },
    {
      "label": "Chainlink",
      "key": "LINK",
      "delta": {
        "amount": "-6825.0000000000",
        "display": "-$6,825.00"
      },
      "cumulative": {
        "amount": "485750.2000000000",
        "display": "$485,750.20"
      },
      "direction": "down",
      "move": {
        "value": "-0.1257253384912959381044487427",
        "display": "-12.57%"
      },
      "units": {
        "units": "2100.00000000",
        "display": "2100"
      },
      "price": {
        "amount": "22.60",
        "display": "$22.60"
      },
      "detail": "-12.57% \u00b7 2100 LINK \u00b7 $22.60",
      "delta_label": "Contribution"
    },
    {
      "label": "Arbitrum",
      "key": "ARB",
      "delta": {
        "amount": "-2835.000000000000",
        "display": "-$2,835.00"
      },
      "cumulative": {
        "amount": "482915.200000000000",
        "display": "$482,915.20"
      },
      "direction": "down",
      "move": {
        "value": "-0.06086956521739130434782608696",
        "display": "-6.09%"
      },
      "units": {
        "units": "50625.00000000",
        "display": "50625"
      },
      "price": {
        "amount": "0.8640",
        "display": "$0.8640"
      },
      "detail": "-6.09% \u00b7 50625 ARB \u00b7 $0.8640",
      "delta_label": "Contribution"
    },
    {
      "label": "USD Coin",
      "key": "USDC",
      "delta": {
        "amount": "0E-10",
        "display": "$0.00"
      },
      "cumulative": {
        "amount": "482915.200000000000",
        "display": "$482,915.20"
      },
      "direction": "up",
      "move": {
        "value": "0E-8",
        "display": "0.00%"
      },
      "units": {
        "units": "51764.00000000",
        "display": "51764"
      },
      "price": {
        "amount": "1.00",
        "display": "$1.00"
      },
      "detail": "0.00% \u00b7 51764 USDC \u00b7 $1.00",
      "delta_label": "Contribution"
    }
  ],
  "annotations": [
    {
      "label": "Bitcoin",
      "text": "$47,359.20"
    },
    {
      "label": "Ethereum",
      "text": "$21,000.00"
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
        "AAVE",
        "ARB",
        "AVAX",
        "BTC",
        "ETH",
        "LINK",
        "SOL",
        "USDC"
      ],
      "pattern": null
    }
  ]
}
```

## `attribution.window.v1`

> The portfolio's move over a chosen window, one bucket per holding, biggest mover first. Not unrealised profit and loss: this compares each holding to what it was worth when the window opened, not to what it cost.

- **Frozen id:** `attribution.window.v1` · **digest:** `abde9901e9d2`
- **Component:** `AttributionWaterfall`
- **Payload type:** `AttributionWindowPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `window`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `fields` | array ≤8 items | list of up to 8 (text), or omit it | `null` | Sections to render; omit for all of them. A section this view does not offer is rejected, never ignored. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `window` | string | string matching ^(1d\|7d\|30d)$ | `"1d"` | How far back the walk looks. A closed set, not a free-form period: an unknown value is a 422, never a best-effort guess. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'attribution.window.v1' | default `"attribution.window.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `window` | enum 1d / 7d / 30d | required | `enum` | variant | input · string matching ^(1d\|7d\|30d)$ |
| `period` | string ≤40 chars | required | `text` | — | — |
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
| `net` | object | required | `container` | — | — |
| `net.label` | string ≤64 chars | required | `text` | — | — |
| `net.amount` | object | required | `container` | — | — |
| `net.amount.amount` | decimal | required | `raw` | — | — |
| `net.amount.display` | string ≤32 chars | required | `display` | — | — |
| `net.percent` | object | required | `container` | — | — |
| `net.percent.value` | decimal | required | `raw` | — | — |
| `net.percent.display` | string ≤16 chars | required | `display` | — | — |
| `net.direction` | enum up / down / flat | required | `enum` | variant | — |
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
| `buckets[].move` | object | required | `container` | — | — |
| `buckets[].move.value` | decimal | required | `raw` | — | — |
| `buckets[].move.display` | string ≤16 chars | required | `display` | — | — |
| `buckets[].opened` | object | required | `container` | — | — |
| `buckets[].opened.amount` | decimal | required | `raw` | — | — |
| `buckets[].opened.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].closed` | object | required | `container` | — | — |
| `buckets[].closed.amount` | decimal | required | `raw` | — | — |
| `buckets[].closed.display` | string ≤32 chars | required | `display` | — | — |
| `buckets[].detail` | string ≤64 chars | required | `text` | — | — |
| `buckets[].delta_label` | string ≤32 chars | required | `text` | — | — |
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
  "view": "attribution.window.v1",
  "title": "What moved your portfolio today",
  "window": "1d",
  "period": "today",
  "start": {
    "label": "Window open",
    "amount": {
      "amount": "480714.150000000000",
      "display": "$480,714.15"
    }
  },
  "end": {
    "label": "Now",
    "amount": {
      "amount": "482915.200000000000",
      "display": "$482,915.20"
    }
  },
  "net": {
    "label": "Net",
    "amount": {
      "amount": "2201.050000000000",
      "display": "+$2,201.05"
    },
    "percent": {
      "value": "0.004578708573483846897371338039",
      "display": "+0.46%"
    },
    "direction": "up"
  },
  "buckets": [
    {
      "label": "Bitcoin",
      "key": "BTC",
      "delta": {
        "amount": "4767.0000000000",
        "display": "+$4,767.00"
      },
      "cumulative": {
        "amount": "485481.150000000000",
        "display": "$485,481.15"
      },
      "direction": "up",
      "move": {
        "value": "0.03662471765085511455308163924",
        "display": "+3.66%"
      },
      "opened": {
        "amount": "130158.0000000000",
        "display": "$130,158.00"
      },
      "closed": {
        "amount": "134925.0000000000",
        "display": "$134,925.00"
      },
      "detail": "+3.66% \u00b7 $130,158.00 \u2192 $134,925.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Aave",
      "key": "AAVE",
      "delta": {
        "amount": "-2012.5000000000",
        "display": "-$2,012.50"
      },
      "cumulative": {
        "amount": "483468.650000000000",
        "display": "$483,468.65"
      },
      "direction": "down",
      "move": {
        "value": "-0.04431599229287090558766859345",
        "display": "-4.43%"
      },
      "opened": {
        "amount": "45412.5000000000",
        "display": "$45,412.50"
      },
      "closed": {
        "amount": "43400.0000000000",
        "display": "$43,400.00"
      },
      "detail": "-4.43% \u00b7 $45,412.50 \u2192 $43,400.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Solana",
      "key": "SOL",
      "delta": {
        "amount": "-1652.2000000000",
        "display": "-$1,652.20"
      },
      "cumulative": {
        "amount": "481816.450000000000",
        "display": "$481,816.45"
      },
      "direction": "down",
      "move": {
        "value": "-0.02806122448979591836734693878",
        "display": "-2.81%"
      },
      "opened": {
        "amount": "58878.4000000000",
        "display": "$58,878.40"
      },
      "closed": {
        "amount": "57226.2000000000",
        "display": "$57,226.20"
      },
      "detail": "-2.81% \u00b7 $58,878.40 \u2192 $57,226.20",
      "delta_label": "Contribution"
    },
    {
      "label": "Chainlink",
      "key": "LINK",
      "delta": {
        "amount": "-1155.0000000000",
        "display": "-$1,155.00"
      },
      "cumulative": {
        "amount": "480661.450000000000",
        "display": "$480,661.45"
      },
      "direction": "down",
      "move": {
        "value": "-0.02375809935205183585313174946",
        "display": "-2.38%"
      },
      "opened": {
        "amount": "48615.0000000000",
        "display": "$48,615.00"
      },
      "closed": {
        "amount": "47460.0000000000",
        "display": "$47,460.00"
      },
      "detail": "-2.38% \u00b7 $48,615.00 \u2192 $47,460.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Ethereum",
      "key": "ETH",
      "delta": {
        "amount": "1140.0000000000",
        "display": "+$1,140.00"
      },
      "cumulative": {
        "amount": "481801.450000000000",
        "display": "$481,801.45"
      },
      "direction": "up",
      "move": {
        "value": "0.01104009296920395119116792562",
        "display": "+1.10%"
      },
      "opened": {
        "amount": "103260.0000000000",
        "display": "$103,260.00"
      },
      "closed": {
        "amount": "104400.0000000000",
        "display": "$104,400.00"
      },
      "detail": "+1.10% \u00b7 $103,260.00 \u2192 $104,400.00",
      "delta_label": "Contribution"
    },
    {
      "label": "Arbitrum",
      "key": "ARB",
      "delta": {
        "amount": "1113.750000000000",
        "display": "+$1,113.75"
      },
      "cumulative": {
        "amount": "482915.200000000000",
        "display": "$482,915.20"
      },
      "direction": "up",
      "move": {
        "value": "0.02612826603325415676959619952",
        "display": "+2.61%"
      },
      "opened": {
        "amount": "42626.250000000000",
        "display": "$42,626.25"
      },
      "closed": {
        "amount": "43740.000000000000",
        "display": "$43,740.00"
      },
      "detail": "+2.61% \u00b7 $42,626.25 \u2192 $43,740.00",
      "delta_label": "Contribution"
    },
    {
      "label": "USD Coin",
      "key": "USDC",
      "delta": {
        "amount": "0E-10",
        "display": "$0.00"
      },
      "cumulative": {
        "amount": "482915.200000000000",
        "display": "$482,915.20"
      },
      "direction": "up",
      "move": {
        "value": "0",
        "display": "0.00%"
      },
      "opened": {
        "amount": "51764.0000000000",
        "display": "$51,764.00"
      },
      "closed": {
        "amount": "51764.0000000000",
        "display": "$51,764.00"
      },
      "detail": "0.00% \u00b7 $51,764.00 \u2192 $51,764.00",
      "delta_label": "Contribution"
    }
  ],
  "annotations": [
    {
      "label": "Bitcoin",
      "text": "+$4,767.00"
    },
    {
      "label": "Aave",
      "text": "-$2,012.50"
    },
    {
      "label": "Net",
      "text": "+$2,201.05 today"
    }
  ]
}
```

## `holdings.allocation.v1`

> Allocation of the portfolio's market value — by holding, asset class or sector — with weight and day change per slice, the count in the donut's centre, and the all-time gain under the total.

- **Frozen id:** `holdings.allocation.v1` · **digest:** `cc5bbfb7061b`
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
| `group_by` | enum holding / asset_class / sector | one of 'holding', 'asset_class', 'sector' | `"holding"` | How the donut is sliced. `holding` is one slice per position; `asset_class` folds them into Layer 1, Layer 2, Infrastructure, DeFi and Stablecoins; `sector` folds them by chain ecosystem. |
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
      "amount": "482915.200000000000",
      "display": "$482,915.20"
    }
  },
  "total_gain": {
    "amount": {
      "amount": "61204.050000000000",
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
    "count": "7",
    "unit": "Holdings"
  },
  "categories": [
    {
      "label": "Bitcoin",
      "key": "BTC",
      "value": {
        "amount": "134925.0000000000",
        "display": "$134,925.00"
      },
      "weight": {
        "value": "0.2793968796177879677425767505",
        "display": "27.94%"
      },
      "change": {
        "value": "0.03662471765085511455308163924",
        "display": "+3.7%"
      },
      "trend": "up"
    },
    {
      "label": "Ethereum",
      "key": "ETH",
      "value": {
        "amount": "104400.0000000000",
        "display": "$104,400.00"
      },
      "weight": {
        "value": "0.2161870241400560595317770076",
        "display": "21.62%"
      },
      "change": {
        "value": "0.01104009296920395119116792562",
        "display": "+1.1%"
      },
      "trend": "up"
    },
    {
      "label": "Solana",
      "key": "SOL",
      "value": {
        "amount": "57226.2000000000",
        "display": "$57,226.20"
      },
      "weight": {
        "value": "0.1185015505827938321262200900",
        "display": "11.85%"
      },
      "change": {
        "value": "-0.02806122448979591836734693878",
        "display": "-2.8%"
      },
      "trend": "down"
    },
    {
      "label": "USD Coin",
      "key": "USDC",
      "value": {
        "amount": "51764.0000000000",
        "display": "$51,764.00"
      },
      "weight": {
        "value": "0.1071906620458415887509856803",
        "display": "10.72%"
      },
      "change": {
        "value": "0",
        "display": "0.0%"
      },
      "trend": "flat"
    },
    {
      "label": "Chainlink",
      "key": "LINK",
      "value": {
        "amount": "47460.0000000000",
        "display": "$47,460.00"
      },
      "weight": {
        "value": "0.09827812419240479487910092704",
        "display": "9.83%"
      },
      "change": {
        "value": "-0.02375809935205183585313174946",
        "display": "-2.4%"
      },
      "trend": "down"
    },
    {
      "label": "Other",
      "key": "other",
      "value": {
        "amount": "87140.000000000000",
        "display": "$87,140.00"
      },
      "weight": {
        "value": "0.1804457594211157569693395445",
        "display": "18.04%"
      },
      "change": {
        "value": "-0.01020857292953387002882253553",
        "display": "-1.0%"
      },
      "trend": "down"
    }
  ]
}
```

## `holdings.positions.v1`

> The Holdings tab: total value with the all-time gain, then one row per position — units and average cost, value, unrealised result, today's move, price and weight — each with the question that hands it to the assistant.

- **Frozen id:** `holdings.positions.v1` · **digest:** `9ff39ae83d7f`
- **Component:** `PositionList`
- **Payload type:** `HoldingsPositionsPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `asset_class`, `query`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `query` | string ≤24 chars | string of up to 24 characters, or omit it | `null` | Narrow the rows to those whose symbol or description contains this text, case-insensitively. Blank or omitted is no filter. |
| `sort` | enum value_desc / value_asc / label | one of 'value_desc', 'value_asc', 'label' | `"value_desc"` | Row order: by value descending, ascending, or by label. |
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `asset_class` | enum all / layer1 / layer2 / stablecoin / defi / infrastructure | one of 'all', 'layer1', 'layer2', 'stablecoin', 'defi', 'infrastructure' | `"all"` | Keep only this asset class; `all` keeps every row. |

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
| `asset_class` | enum all / layer1 / layer2 / stablecoin / defi / infrastructure | default `"all"` | `enum` | variant | input · one of 'all', 'layer1', 'layer2', 'stablecoin', 'defi', 'infrastructure' |
| `query` | string ≤24 chars | default `null` | `text` | null | input · string of up to 24 characters, or omit it |
| `filters` | array ≤8 items | required | `container` | empty | — |
| `filters[].key` | enum all / layer1 / layer2 / stablecoin / defi / infrastructure | required | `enum` | variant | — |
| `filters[].label` | string ≤16 chars | required | `text` | — | — |
| `empty` | string ≤48 chars | default `"No holdings match this filter."` | `text` | — | — |
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
      "amount": "482915.200000000000",
      "display": "$482,915.20"
    }
  },
  "gain": {
    "amount": {
      "amount": "61204.050000000000",
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
  "asset_class": "all",
  "query": null,
  "filters": [
    {
      "key": "all",
      "label": "All"
    },
    {
      "key": "layer1",
      "label": "Layer 1"
    },
    {
      "key": "layer2",
      "label": "Layer 2"
    },
    {
      "key": "infrastructure",
      "label": "Infrastructure"
    },
    {
      "key": "defi",
      "label": "DeFi"
    },
    {
      "key": "stablecoin",
      "label": "Stablecoins"
    }
  ],
  "empty": "No holdings match this filter.",
  "positions": [
    {
      "symbol": "BTC",
      "name": "Bitcoin",
      "detail": "2.1 BTC \u00b7 avg $41,698.00",
      "value": {
        "amount": "134925.0000000000",
        "display": "$134,925.00"
      },
      "unrealized": {
        "amount": {
          "amount": "47359.2000000000",
          "display": "+$47,359"
        },
        "percent": {
          "value": "0.5408412873519113626552832270",
          "display": "+54.1%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "0.03662471765085511455308163924",
        "display": "+3.7%"
      },
      "day_trend": "up",
      "price": {
        "amount": "64250.00",
        "display": "$64,250.00"
      },
      "weight": {
        "value": "0.2793968796177879677425767505",
        "display": "27.9%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my BTC position"
      }
    },
    {
      "symbol": "ETH",
      "name": "Ethereum",
      "detail": "30 ETH \u00b7 avg $2,780.00",
      "value": {
        "amount": "104400.0000000000",
        "display": "$104,400.00"
      },
      "unrealized": {
        "amount": {
          "amount": "21000.0000000000",
          "display": "+$21,000"
        },
        "percent": {
          "value": "0.2517985611510791366906474820",
          "display": "+25.2%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "0.01104009296920395119116792562",
        "display": "+1.1%"
      },
      "day_trend": "up",
      "price": {
        "amount": "3480.00",
        "display": "$3,480.00"
      },
      "weight": {
        "value": "0.2161870241400560595317770076",
        "display": "21.6%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my ETH position"
      }
    },
    {
      "symbol": "SOL",
      "name": "Solana",
      "detail": "375.5 SOL \u00b7 avg $177.70",
      "value": {
        "amount": "57226.2000000000",
        "display": "$57,226.20"
      },
      "unrealized": {
        "amount": {
          "amount": "-9500.1500000000",
          "display": "-$9,500"
        },
        "percent": {
          "value": "-0.1423747889701744513224535734",
          "display": "-14.2%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.02806122448979591836734693878",
        "display": "-2.8%"
      },
      "day_trend": "down",
      "price": {
        "amount": "152.40",
        "display": "$152.40"
      },
      "weight": {
        "value": "0.1185015505827938321262200900",
        "display": "11.9%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my SOL position"
      }
    },
    {
      "symbol": "LINK",
      "name": "Chainlink",
      "detail": "2100 LINK \u00b7 avg $25.85",
      "value": {
        "amount": "47460.0000000000",
        "display": "$47,460.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-6825.0000000000",
          "display": "-$6,825"
        },
        "percent": {
          "value": "-0.1257253384912959381044487427",
          "display": "-12.6%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "-0.02375809935205183585313174946",
        "display": "-2.4%"
      },
      "day_trend": "down",
      "price": {
        "amount": "22.60",
        "display": "$22.60"
      },
      "weight": {
        "value": "0.09827812419240479487910092704",
        "display": "9.8%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my LINK position"
      }
    },
    {
      "symbol": "ARB",
      "name": "Arbitrum",
      "detail": "50625 ARB \u00b7 avg $0.92",
      "value": {
        "amount": "43740.000000000000",
        "display": "$43,740.00"
      },
      "unrealized": {
        "amount": {
          "amount": "-2835.000000000000",
          "display": "-$2,835"
        },
        "percent": {
          "value": "-0.06086956521739130434782608696",
          "display": "-6.1%"
        },
        "trend": "down",
        "period": "all-time"
      },
      "day": {
        "value": "0.02612826603325415676959619952",
        "display": "+2.6%"
      },
      "day_trend": "up",
      "price": {
        "amount": "0.8640",
        "display": "$0.86"
      },
      "weight": {
        "value": "0.09057490838971314218314105665",
        "display": "9.1%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my ARB position"
      }
    },
    {
      "symbol": "AAVE",
      "name": "Aave",
      "detail": "175 AAVE \u00b7 avg $179.40",
      "value": {
        "amount": "43400.0000000000",
        "display": "$43,400.00"
      },
      "unrealized": {
        "amount": {
          "amount": "12005.0000000000",
          "display": "+$12,005"
        },
        "percent": {
          "value": "0.3823857302118171683389074693",
          "display": "+38.2%"
        },
        "trend": "up",
        "period": "all-time"
      },
      "day": {
        "value": "-0.04431599229287090558766859345",
        "display": "-4.4%"
      },
      "day_trend": "down",
      "price": {
        "amount": "248.00",
        "display": "$248.00"
      },
      "weight": {
        "value": "0.08987085103140261478619848785",
        "display": "9.0%"
      },
      "is_cash": false,
      "ask": {
        "text": "Tell me about my AAVE position"
      }
    },
    {
      "symbol": "USDC",
      "name": "USD Coin",
      "detail": "Settlement fund",
      "value": {
        "amount": "51764.0000000000",
        "display": "$51,764.00"
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
        "value": "0.1071906620458415887509856803",
        "display": "10.7%"
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

- **Frozen id:** `order.ticket.v1` · **digest:** `4f00c29a4c39`
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
| `symbol` | enum AAVE / ARB / AVAX / BTC / ETH / LINK / SOL / USDC | one of 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' | `"BTC"` | Asset the order is written for, from the market reference. |
| `side` | enum buy / sell | one of 'buy', 'sell' | `"buy"` | Which way the order goes; `sell` disposes of units held. |
| `size` | string | string matching ^[0-9]{1,9}(\.[0-9]{1,8})?$ | `"1"` | How big the order is, as a decimal string (ADR-E D-5). |
| `size_in` | enum units / usd | one of 'units', 'usd' | `"units"` | What `size` counts: units of the asset, or US dollars. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'order.ticket.v1' | default `"order.ticket.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `symbol` | string ≤10 chars | required | `text` | — | input · one of 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' |
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
  "symbol": "BTC",
  "name": "Bitcoin",
  "side": "buy",
  "size": "1",
  "size_in": "units",
  "quantity": {
    "units": "1",
    "display": "1"
  },
  "entry_price": {
    "amount": "64250.00",
    "display": "$64,250.00"
  },
  "notional": {
    "label": "Order value",
    "amount": {
      "amount": "64250.00",
      "display": "$64,250.00"
    }
  },
  "inputs": [
    {
      "option": "symbol",
      "label": "Asset",
      "control": "choice",
      "value": "BTC",
      "choices": [
        "AAVE",
        "ARB",
        "AVAX",
        "BTC",
        "ETH",
        "LINK",
        "SOL",
        "USDC"
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

## `order.ticket.v2`

> Multi-leg draft order: each leg struck at its reference price with its weight in the order, the order's impact — total, fees, cash remaining, the group's weight before and after — and whether the available cash covers it. Editing a leg re-renders it; it places nothing.

- **Frozen id:** `order.ticket.v2` · **digest:** `8cd79663e799`
- **Component:** `MultiLegOrderTicket`
- **Payload type:** `OrderTicketV2Payload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `side`, `legs`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `legs` | string ≤149 chars | string matching ^[A-Z]{2,10}:[0-9]{1,9}(\.[0-9]{1,8})?(,[A-Z]{2,10}:[0-9]{1,9}(\.[0-9]{1,8})?){0,4}$ | `"BTC:0.06,ETH:1.0,SOL:16"` | The legs of the draft as `TICKER:UNITS` pairs separated by commas, one to five of them, units up to eight decimals, each ticker from the market reference and named once. Every rendered leg carries the value a `+` or `-` sends back, so a stepper edit is this option re-sent with one number moved by that asset's own step. |
| `side` | enum buy / sell | one of 'buy', 'sell' | `"buy"` | Which way every leg goes. A `buy` draws on the portfolio's cash and is blocked when it would exceed it; a `sell` raises cash. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'order.ticket.v2' | default `"order.ticket.v2"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `badge` | enum editable / blocked | required | `enum` | variant | — |
| `side` | enum buy / sell | required | `enum` | variant | input · one of 'buy', 'sell' |
| `legs` | string ≤149 chars | required | `text` | — | input · string matching ^[A-Z]{2,10}:[0-9]{1,9}(\.[0-9]{1,8})?(,[A-Z]{2,10}:[0-9]{1,9}(\.[0-9]{1,8})?){0,4}$ |
| `lines` | array ≤5 items | required | `container` | empty | — |
| `lines[].key` | string ≤10 chars | required | `text` | — | — |
| `lines[].symbol` | string ≤10 chars | required | `text` | — | — |
| `lines[].name` | string ≤64 chars | required | `text` | — | — |
| `lines[].price` | object | required | `container` | — | — |
| `lines[].price.amount` | decimal | required | `raw` | — | — |
| `lines[].price.display` | string ≤32 chars | required | `display` | — | — |
| `lines[].quantity` | object | required | `container` | — | — |
| `lines[].quantity.units` | decimal | required | `raw` | — | — |
| `lines[].quantity.display` | string ≤32 chars | required | `display` | — | — |
| `lines[].notional` | object | required | `container` | — | — |
| `lines[].notional.amount` | decimal | required | `raw` | — | — |
| `lines[].notional.display` | string ≤32 chars | required | `display` | — | — |
| `lines[].weight` | object | required | `container` | — | — |
| `lines[].weight.value` | decimal | required | `raw` | — | — |
| `lines[].weight.display` | string ≤16 chars | required | `display` | — | — |
| `lines[].increment` | string ≤149 chars | required | `text` | null | — |
| `lines[].decrement` | string ≤149 chars | required | `text` | null | — |
| `impact` | object | required | `container` | — | — |
| `impact.total` | object | required | `container` | — | — |
| `impact.total.label` | string ≤64 chars | required | `text` | — | — |
| `impact.total.amount` | object | required | `container` | — | — |
| `impact.total.amount.amount` | decimal | required | `raw` | — | — |
| `impact.total.amount.display` | string ≤32 chars | required | `display` | — | — |
| `impact.fees` | object | required | `container` | — | — |
| `impact.fees.label` | string ≤64 chars | required | `text` | — | — |
| `impact.fees.amount` | object | required | `container` | — | — |
| `impact.fees.amount.amount` | decimal | required | `raw` | — | — |
| `impact.fees.amount.display` | string ≤32 chars | required | `display` | — | — |
| `impact.cash_remaining` | object | required | `container` | — | — |
| `impact.cash_remaining.label` | string ≤64 chars | required | `text` | — | — |
| `impact.cash_remaining.amount` | object | required | `container` | — | — |
| `impact.cash_remaining.amount.amount` | decimal | required | `raw` | — | — |
| `impact.cash_remaining.amount.display` | string ≤32 chars | required | `display` | — | — |
| `impact.weight_shifts` | array ≤5 items | required | `container` | empty | — |
| `impact.weight_shifts[].label` | string ≤64 chars | required | `text` | — | — |
| `impact.weight_shifts[].key` | string ≤32 chars | required | `text` | — | — |
| `impact.weight_shifts[].before` | object | required | `container` | — | — |
| `impact.weight_shifts[].before.value` | decimal | required | `raw` | — | — |
| `impact.weight_shifts[].before.display` | string ≤16 chars | required | `display` | — | — |
| `impact.weight_shifts[].after` | object | required | `container` | — | — |
| `impact.weight_shifts[].after.value` | decimal | required | `raw` | — | — |
| `impact.weight_shifts[].after.display` | string ≤16 chars | required | `display` | — | — |
| `constraints` | object | required | `container` | — | — |
| `constraints.max_cash` | object | required | `container` | — | — |
| `constraints.max_cash.label` | string ≤64 chars | required | `text` | — | — |
| `constraints.max_cash.amount` | object | required | `container` | — | — |
| `constraints.max_cash.amount.amount` | decimal | required | `raw` | — | — |
| `constraints.max_cash.amount.display` | string ≤32 chars | required | `display` | — | — |
| `constraints.breach` | enum none / over_cash | required | `enum` | variant | — |
| `constraints.shortfall` | object | default `null` | `text` | null | — |
| `constraints.message` | string ≤160 chars | default `null` | `text` | null | — |
| `disclosure` | string ≤300 chars | required | `text` | — | — |
| `effect` | const 'recalculate' | default `"recalculate"` | `constant` | — | — |

### When the agent picks this

- **Use it when** the user expresses buy or sell INTENT that resolves to a concrete, editable order — including vague intent such as "put ~$10k into semis, keep it diversified". Propose legs through `draft_order`; the impact (weights, cash, shares) is always shown so the consequences are visible before anything is confirmed, and the backend recomputes it on every edit.
- **Do not use it for** placing or confirming an order in prose — nothing here executes, and the ticket says so. A single asset with no impact panel is `order.ticket.v1`; what a proposed sale realises under each lot method is `scenario.comparison.v1`. Never recompute a figure the payload already carries.

### Actions

_This surface sends nothing back: tapping it starts no turn._

### Example payload

```json
{
  "view": "order.ticket.v2",
  "title": "Draft order \u00b7 Buy \u00b7 3 legs",
  "badge": "editable",
  "side": "buy",
  "legs": "BTC:0.06,ETH:1.0,SOL:16",
  "lines": [
    {
      "key": "BTC",
      "symbol": "BTC",
      "name": "Bitcoin",
      "price": {
        "amount": "64250.00",
        "display": "$64,250.00"
      },
      "quantity": {
        "units": "0.06",
        "display": "0.06"
      },
      "notional": {
        "amount": "3855.0000",
        "display": "$3,855.00"
      },
      "weight": {
        "value": "0.3944379642703665050033765118",
        "display": "39.44%"
      },
      "increment": "BTC:0.07,ETH:1.0,SOL:16",
      "decrement": "BTC:0.05,ETH:1.0,SOL:16"
    },
    {
      "key": "ETH",
      "symbol": "ETH",
      "name": "Ethereum",
      "price": {
        "amount": "3480.00",
        "display": "$3,480.00"
      },
      "quantity": {
        "units": "1.0",
        "display": "1"
      },
      "notional": {
        "amount": "3480.000",
        "display": "$3,480.00"
      },
      "weight": {
        "value": "0.3560685124930934986800908589",
        "display": "35.61%"
      },
      "increment": "BTC:0.06,ETH:1.1,SOL:16",
      "decrement": "BTC:0.06,ETH:0.9,SOL:16"
    },
    {
      "key": "SOL",
      "symbol": "SOL",
      "name": "Solana",
      "price": {
        "amount": "152.40",
        "display": "$152.40"
      },
      "quantity": {
        "units": "16",
        "display": "16"
      },
      "notional": {
        "amount": "2438.40",
        "display": "$2,438.40"
      },
      "weight": {
        "value": "0.2494935232365399963165326294",
        "display": "24.95%"
      },
      "increment": "BTC:0.06,ETH:1.0,SOL:17",
      "decrement": "BTC:0.06,ETH:1.0,SOL:15"
    }
  ],
  "impact": {
    "total": {
      "label": "Total order",
      "amount": {
        "amount": "9773.4000",
        "display": "$9,773.40"
      }
    },
    "fees": {
      "label": "Est. fees \u00b7 sim",
      "amount": {
        "amount": "0",
        "display": "$0.00"
      }
    },
    "cash_remaining": {
      "label": "Cash remaining",
      "amount": {
        "amount": "41990.6000000000",
        "display": "$41,990.60"
      }
    },
    "weight_shifts": [
      {
        "label": "Portfolio weight \u00b7 Bitcoin",
        "key": "bitcoin",
        "before": {
          "value": "0.2793968796177879677425767505",
          "display": "27.94%"
        },
        "after": {
          "value": "0.2873796476068676239637932291",
          "display": "28.74%"
        }
      },
      {
        "label": "Portfolio weight \u00b7 Ethereum",
        "key": "ethereum",
        "before": {
          "value": "0.4949109077535766113802174792",
          "display": "49.49%"
        },
        "after": {
          "value": "0.5021171418915784800312767128",
          "display": "50.21%"
        }
      },
      {
        "label": "Portfolio weight \u00b7 Solana",
        "key": "solana",
        "before": {
          "value": "0.1185015505827938321262200900",
          "display": "11.85%"
        },
        "after": {
          "value": "0.1235508842960420380224105599",
          "display": "12.36%"
        }
      }
    ]
  },
  "constraints": {
    "max_cash": {
      "label": "Available cash",
      "amount": {
        "amount": "51764.0000000000",
        "display": "$51,764.00"
      }
    },
    "breach": "none",
    "shortfall": null,
    "message": null
  },
  "disclosure": "Illustrative draft. This showcase has no broker and no execution: stepping a leg re-renders these figures, fees are simulated at zero, and nothing is ever sent, placed or settled.",
  "effect": "recalculate"
}
```

## `payoff.curve.v1`

> Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff.

- **Frozen id:** `payoff.curve.v1` · **digest:** `922cd5dac6f0`
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
| `symbol` | enum AAVE / ARB / AVAX / BTC / ETH / LINK / SOL / USDC | one of 'AAVE', 'ARB', 'AVAX', 'BTC', 'ETH', 'LINK', 'SOL', 'USDC' | `"SOL"` | Asset the order is for. |
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
  "title": "Payoff across a price range: buy Solana",
  "disclosure": "Illustrative linear spot payoff on the demo portfolio's simulated prices: profit or loss is (price - entry) x quantity, with no fees, no slippage and no financing. There is no strike, no expiry, no implied volatility and no time decay behind this line. A sell is the mirror of the position and leaves no position to value.",
  "markers": {
    "break_even": {
      "label": "Break-even",
      "at": {
        "amount": "152.40",
        "display": "$152.40"
      }
    },
    "current": {
      "label": "Current price",
      "at": {
        "amount": "152.40",
        "display": "$152.40"
      }
    }
  },
  "totals": [
    {
      "label": "Entry price",
      "amount": {
        "amount": "152.40",
        "display": "$152.40"
      }
    },
    {
      "label": "Break-even price",
      "amount": {
        "amount": "152.40",
        "display": "$152.40"
      }
    },
    {
      "label": "Notional",
      "amount": {
        "amount": "499.9999999999999999999999999",
        "display": "$500.00"
      }
    }
  ],
  "series": [
    {
      "name": "Profit / loss",
      "points": [
        {
          "label": "$106.68",
          "at": {
            "amount": "106.680",
            "display": "$106.68"
          },
          "value": {
            "amount": "-150.0000000000000000000000000",
            "display": "-$150.00"
          }
        },
        {
          "label": "$110.49",
          "at": {
            "amount": "110.49000",
            "display": "$110.49"
          },
          "value": {
            "amount": "-137.5000000000000000000000000",
            "display": "-$137.50"
          }
        },
        {
          "label": "$114.30",
          "at": {
            "amount": "114.3000",
            "display": "$114.30"
          },
          "value": {
            "amount": "-125.0000000000000000000000000",
            "display": "-$125.00"
          }
        },
        {
          "label": "$118.11",
          "at": {
            "amount": "118.11000",
            "display": "$118.11"
          },
          "value": {
            "amount": "-112.5000000000000000000000000",
            "display": "-$112.50"
          }
        },
        {
          "label": "$121.92",
          "at": {
            "amount": "121.920",
            "display": "$121.92"
          },
          "value": {
            "amount": "-99.99999999999999999999999999",
            "display": "-$100.00"
          }
        },
        {
          "label": "$125.73",
          "at": {
            "amount": "125.73000",
            "display": "$125.73"
          },
          "value": {
            "amount": "-87.49999999999999999999999999",
            "display": "-$87.50"
          }
        },
        {
          "label": "$129.54",
          "at": {
            "amount": "129.5400",
            "display": "$129.54"
          },
          "value": {
            "amount": "-74.99999999999999999999999999",
            "display": "-$75.00"
          }
        },
        {
          "label": "$133.35",
          "at": {
            "amount": "133.35000",
            "display": "$133.35"
          },
          "value": {
            "amount": "-62.49999999999999999999999999",
            "display": "-$62.50"
          }
        },
        {
          "label": "$137.16",
          "at": {
            "amount": "137.160",
            "display": "$137.16"
          },
          "value": {
            "amount": "-49.99999999999999999999999999",
            "display": "-$50.00"
          }
        },
        {
          "label": "$140.97",
          "at": {
            "amount": "140.97000",
            "display": "$140.97"
          },
          "value": {
            "amount": "-37.49999999999999999999999999",
            "display": "-$37.50"
          }
        },
        {
          "label": "$144.78",
          "at": {
            "amount": "144.7800",
            "display": "$144.78"
          },
          "value": {
            "amount": "-25.00000000000000000000000000",
            "display": "-$25.00"
          }
        },
        {
          "label": "$148.59",
          "at": {
            "amount": "148.59000",
            "display": "$148.59"
          },
          "value": {
            "amount": "-12.50000000000000000000000000",
            "display": "-$12.50"
          }
        },
        {
          "label": "$152.40",
          "at": {
            "amount": "152.400",
            "display": "$152.40"
          },
          "value": {
            "amount": "0E-30",
            "display": "$0.00"
          }
        },
        {
          "label": "$156.21",
          "at": {
            "amount": "156.21000",
            "display": "$156.21"
          },
          "value": {
            "amount": "12.50000000000000000000000000",
            "display": "$12.50"
          }
        },
        {
          "label": "$160.02",
          "at": {
            "amount": "160.0200",
            "display": "$160.02"
          },
          "value": {
            "amount": "25.00000000000000000000000000",
            "display": "$25.00"
          }
        },
        {
          "label": "$163.83",
          "at": {
            "amount": "163.83000",
            "display": "$163.83"
          },
          "value": {
            "amount": "37.49999999999999999999999999",
            "display": "$37.50"
          }
        },
        {
          "label": "$167.64",
          "at": {
            "amount": "167.640",
            "display": "$167.64"
          },
          "value": {
            "amount": "49.99999999999999999999999999",
            "display": "$50.00"
          }
        },
        {
          "label": "$171.45",
          "at": {
            "amount": "171.45000",
            "display": "$171.45"
          },
          "value": {
            "amount": "62.49999999999999999999999999",
            "display": "$62.50"
          }
        },
        {
          "label": "$175.26",
          "at": {
            "amount": "175.2600",
            "display": "$175.26"
          },
          "value": {
            "amount": "74.99999999999999999999999999",
            "display": "$75.00"
          }
        },
        {
          "label": "$179.07",
          "at": {
            "amount": "179.07000",
            "display": "$179.07"
          },
          "value": {
            "amount": "87.49999999999999999999999999",
            "display": "$87.50"
          }
        },
        {
          "label": "$182.88",
          "at": {
            "amount": "182.880",
            "display": "$182.88"
          },
          "value": {
            "amount": "99.99999999999999999999999999",
            "display": "$100.00"
          }
        },
        {
          "label": "$186.69",
          "at": {
            "amount": "186.69000",
            "display": "$186.69"
          },
          "value": {
            "amount": "112.5000000000000000000000000",
            "display": "$112.50"
          }
        },
        {
          "label": "$190.50",
          "at": {
            "amount": "190.5000",
            "display": "$190.50"
          },
          "value": {
            "amount": "125.0000000000000000000000000",
            "display": "$125.00"
          }
        },
        {
          "label": "$194.31",
          "at": {
            "amount": "194.31000",
            "display": "$194.31"
          },
          "value": {
            "amount": "137.5000000000000000000000000",
            "display": "$137.50"
          }
        },
        {
          "label": "$198.12",
          "at": {
            "amount": "198.120",
            "display": "$198.12"
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
      "text": "$152.40"
    },
    {
      "label": "Break-even",
      "text": "$152.40"
    },
    {
      "label": "Low",
      "text": "at $106.68: -$150.00"
    },
    {
      "label": "High",
      "text": "at $198.12: $150.00"
    }
  ]
}
```

## `portfolio.summary.v1`

> The Home hero: total value, the change over a selected period with its direction, a thirty-day sparkline, the owner's greeting, suggested questions for the assistant and the day's top movers.

- **Frozen id:** `portfolio.summary.v1` · **digest:** `191db33e1a5f`
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
      "amount": "482915.200000000000",
      "display": "$482,915.20"
    }
  },
  "change": {
    "amount": {
      "amount": "2201.050000000000",
      "display": "+$2,201.05"
    },
    "percent": {
      "value": "0.004578708573483846897371338039",
      "display": "+0.46%"
    },
    "trend": "up",
    "period": "today"
  },
  "spark": [
    {
      "label": "12/17/2025",
      "value": {
        "amount": "480484.095000000000",
        "display": "$480,484.10"
      }
    },
    {
      "label": "12/18/2025",
      "value": {
        "amount": "486915.890000000000",
        "display": "$486,915.89"
      }
    },
    {
      "label": "12/19/2025",
      "value": {
        "amount": "491036.508000000000",
        "display": "$491,036.51"
      }
    },
    {
      "label": "12/20/2025",
      "value": {
        "amount": "485883.030500000000",
        "display": "$485,883.03"
      }
    },
    {
      "label": "12/21/2025",
      "value": {
        "amount": "482892.777500000000",
        "display": "$482,892.78"
      }
    },
    {
      "label": "12/22/2025",
      "value": {
        "amount": "492427.372500000000",
        "display": "$492,427.37"
      }
    },
    {
      "label": "12/23/2025",
      "value": {
        "amount": "488710.588000000000",
        "display": "$488,710.59"
      }
    },
    {
      "label": "12/24/2025",
      "value": {
        "amount": "480551.703000000000",
        "display": "$480,551.70"
      }
    },
    {
      "label": "12/25/2025",
      "value": {
        "amount": "488339.434500000000",
        "display": "$488,339.43"
      }
    },
    {
      "label": "12/26/2025",
      "value": {
        "amount": "490297.782500000000",
        "display": "$490,297.78"
      }
    },
    {
      "label": "12/27/2025",
      "value": {
        "amount": "493649.927000000000",
        "display": "$493,649.93"
      }
    },
    {
      "label": "12/28/2025",
      "value": {
        "amount": "494705.473000000000",
        "display": "$494,705.47"
      }
    },
    {
      "label": "12/29/2025",
      "value": {
        "amount": "474839.212500000000",
        "display": "$474,839.21"
      }
    },
    {
      "label": "12/30/2025",
      "value": {
        "amount": "481748.042500000000",
        "display": "$481,748.04"
      }
    },
    {
      "label": "12/31/2025",
      "value": {
        "amount": "501149.487500000000",
        "display": "$501,149.49"
      }
    },
    {
      "label": "01/01/2026",
      "value": {
        "amount": "463009.932000000000",
        "display": "$463,009.93"
      }
    },
    {
      "label": "01/02/2026",
      "value": {
        "amount": "467125.702500000000",
        "display": "$467,125.70"
      }
    },
    {
      "label": "01/03/2026",
      "value": {
        "amount": "491060.220000000000",
        "display": "$491,060.22"
      }
    },
    {
      "label": "01/04/2026",
      "value": {
        "amount": "468240.230500000000",
        "display": "$468,240.23"
      }
    },
    {
      "label": "01/05/2026",
      "value": {
        "amount": "494488.317500000000",
        "display": "$494,488.32"
      }
    },
    {
      "label": "01/06/2026",
      "value": {
        "amount": "479833.165000000000",
        "display": "$479,833.16"
      }
    },
    {
      "label": "01/07/2026",
      "value": {
        "amount": "481395.398000000000",
        "display": "$481,395.40"
      }
    },
    {
      "label": "01/08/2026",
      "value": {
        "amount": "496046.592500000000",
        "display": "$496,046.59"
      }
    },
    {
      "label": "01/09/2026",
      "value": {
        "amount": "492122.335500000000",
        "display": "$492,122.34"
      }
    },
    {
      "label": "01/10/2026",
      "value": {
        "amount": "487632.935000000000",
        "display": "$487,632.94"
      }
    },
    {
      "label": "01/11/2026",
      "value": {
        "amount": "489503.603000000000",
        "display": "$489,503.60"
      }
    },
    {
      "label": "01/12/2026",
      "value": {
        "amount": "472249.773000000000",
        "display": "$472,249.77"
      }
    },
    {
      "label": "01/13/2026",
      "value": {
        "amount": "483591.415000000000",
        "display": "$483,591.42"
      }
    },
    {
      "label": "01/14/2026",
      "value": {
        "amount": "480714.150000000000",
        "display": "$480,714.15"
      }
    },
    {
      "label": "01/15/2026",
      "value": {
        "amount": "482915.200000000000",
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
      "text": "Tax impact of selling BTC?"
    },
    {
      "text": "Build a $10k order in tech"
    }
  ],
  "movers_title": "Top movers today",
  "movers": [
    {
      "symbol": "AVAX",
      "name": "Avalanche",
      "price": {
        "amount": "41.80",
        "display": "$41.80"
      },
      "change": {
        "value": "-0.06278026905829596412556053812",
        "display": "-6.3%"
      },
      "trend": "down"
    },
    {
      "symbol": "AAVE",
      "name": "Aave",
      "price": {
        "amount": "248.00",
        "display": "$248.00"
      },
      "change": {
        "value": "-0.04431599229287090558766859345",
        "display": "-4.4%"
      },
      "trend": "down"
    },
    {
      "symbol": "BTC",
      "name": "Bitcoin",
      "price": {
        "amount": "64250.00",
        "display": "$64,250.00"
      },
      "change": {
        "value": "0.03662471765085511455308163924",
        "display": "+3.7%"
      },
      "trend": "up"
    }
  ]
}
```

## `scenario.comparison.v1`

> The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method.

- **Frozen id:** `scenario.comparison.v1` · **digest:** `f3cae9fd15c1`
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
    "label": "Bitcoin",
    "symbol": "BTC",
    "quantity_display": "0.25",
    "price": {
      "amount": "64250.00",
      "display": "$64,250.00"
    },
    "proceeds": {
      "amount": "16062.5000000000",
      "display": "$16,062.50"
    }
  },
  "columns": [
    {
      "method": "FIFO",
      "label": "FIFO \u2014 oldest lots first",
      "cost_basis": {
        "amount": "9000.00",
        "display": "$9,000.00"
      },
      "realized_pl": {
        "amount": "7062.5000000000",
        "display": "+$7,062.50"
      },
      "short_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "long_term_pl": {
        "amount": "7062.5000000000",
        "display": "+$7,062.50"
      },
      "short_term_lots": 0,
      "long_term_lots": 1,
      "lots": [
        "lot-btc-01"
      ]
    },
    {
      "method": "LIFO",
      "label": "LIFO \u2014 newest lots first",
      "cost_basis": {
        "amount": "10617.00",
        "display": "$10,617.00"
      },
      "realized_pl": {
        "amount": "5445.5000000000",
        "display": "+$5,445.50"
      },
      "short_term_pl": {
        "amount": "5445.5000000000",
        "display": "+$5,445.50"
      },
      "long_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "short_term_lots": 1,
      "long_term_lots": 0,
      "lots": [
        "lot-btc-02"
      ]
    },
    {
      "method": "HIFO",
      "label": "HIFO \u2014 dearest lots first",
      "cost_basis": {
        "amount": "10617.00",
        "display": "$10,617.00"
      },
      "realized_pl": {
        "amount": "5445.5000000000",
        "display": "+$5,445.50"
      },
      "short_term_pl": {
        "amount": "5445.5000000000",
        "display": "+$5,445.50"
      },
      "long_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "short_term_lots": 1,
      "long_term_lots": 0,
      "lots": [
        "lot-btc-02"
      ]
    }
  ],
  "spread": {
    "amount": {
      "amount": "1617.0000000000",
      "display": "$1,617.00"
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

- **Frozen id:** `taxlots.table.v1` · **digest:** `0556567d7b94`
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
| `symbol` | string ≤10 chars | string matching ^[A-Za-z]{2,10}$ | `"BTC"` | Ticker being sold, in any case. |
| `quantity` | string | string matching ^\d{1,12}(\.\d{1,8})?$ | `"0.75"` | Units to sell, written as a decimal string ('0.5'). A dollar-sized ask is resolved to units by the `simulate_sale` tool; copy the units it returned rather than dividing (spec 0015 OD-4). |
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
| `realized.direction` | enum up / down / flat | required | `enum` | variant | — |
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
| `lots[].holding_period_display` | string ≤16 chars | required | `text` | — | — |
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
  "subtitle": "Sell 0.75 BTC under FIFO",
  "proceeds": {
    "label": "Proceeds",
    "amount": {
      "amount": "48187.5000000000",
      "display": "$48,187.50"
    }
  },
  "cost_basis": {
    "label": "Cost basis",
    "amount": {
      "amount": "30234.00",
      "display": "$30,234.00"
    }
  },
  "realized": {
    "label": "Realised P/L",
    "amount": {
      "amount": "17953.5000000000",
      "display": "+$17,953.50"
    },
    "direction": "up"
  },
  "by_term": [
    {
      "label": "Short-term",
      "term": "short",
      "lots": 1,
      "realized": {
        "amount": "10891.0000000000",
        "display": "+$10,891.00"
      }
    },
    {
      "label": "Long-term",
      "term": "long",
      "lots": 1,
      "realized": {
        "amount": "7062.5000000000",
        "display": "+$7,062.50"
      }
    }
  ],
  "lots": [
    {
      "label": "lot-btc-01",
      "acquired_on": "2025-01-13",
      "acquired_on_display": "01/13/2025",
      "term": "long",
      "holding_period_display": "1.0 yr",
      "units": "0.25000000",
      "units_display": "0.25",
      "cost_basis": {
        "amount": "9000.00",
        "display": "$9,000.00"
      },
      "proceeds": {
        "amount": "16062.5000000000",
        "display": "$16,062.50"
      },
      "gain_loss": {
        "amount": "7062.5000000000",
        "display": "+$7,062.50"
      },
      "trend": "up",
      "fully_sold": true
    },
    {
      "label": "lot-btc-02",
      "acquired_on": "2025-01-17",
      "acquired_on_display": "01/17/2025",
      "term": "short",
      "holding_period_display": "12 mo",
      "units": "0.50000000",
      "units_display": "0.5",
      "cost_basis": {
        "amount": "21234.00",
        "display": "$21,234.00"
      },
      "proceeds": {
        "amount": "32125.0000000000",
        "display": "$32,125.00"
      },
      "gain_loss": {
        "amount": "10891.0000000000",
        "display": "+$10,891.00"
      },
      "trend": "up",
      "fully_sold": false
    }
  ]
}
```
