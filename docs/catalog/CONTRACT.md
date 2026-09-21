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

| Frozen id | Digest | Fields | Inputs | Purpose |
|---|---|---|---|---|
| [`attribution.waterfall.v1`](#attributionwaterfallv1) | `e866358af26d` | 24 | read-only | Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first. |
| [`holdings.allocation.v1`](#holdingsallocationv1) | `63d89e469006` | 16 | read-only | Allocation by holding: market value and portfolio weight per symbol, with a residual Other bucket for everything beyond top_n. |
| [`order.ticket.v1`](#orderticketv1) | `0a2904b9b52d` | 25 | `symbol`, `side` | Order ticket: a proposed buy or sell with its units, entry price and notional, plus the bounded inputs that re-render it. It places nothing. |
| [`payoff.curve.v1`](#payoffcurvev1) | `205668c78931` | 18 | read-only | Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff. |
| [`scenario.comparison.v1`](#scenariocomparisonv1) | `d996313186c4` | 40 | `subject.symbol` | The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method. |
| [`taxlots.table.v1`](#taxlotstablev1) | `dfc041e6746d` | 49 | read-only | Tax-lot table for a proposed sale: the lots it consumes under FIFO, LIFO or HIFO, each with its holding period, and the realised result split short-term vs long-term. Nothing is traded. |

## `attribution.waterfall.v1`

> Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first.

- **Frozen id:** `attribution.waterfall.v1` · **digest:** `e866358af26d`
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

### Example payload

```json
{
  "view": "attribution.waterfall.v1",
  "title": "Unrealised P/L attribution",
  "start": {
    "label": "Cost basis",
    "amount": {
      "amount": "56925.00",
      "display": "$56,925.00"
    }
  },
  "end": {
    "label": "Market value",
    "amount": {
      "amount": "65038.600000000000",
      "display": "$65,038.60"
    }
  },
  "buckets": [
    {
      "label": "Bitcoin",
      "delta": {
        "amount": "10230.000000",
        "display": "$10,230.00"
      },
      "cumulative": {
        "amount": "67155.000000",
        "display": "$67,155.00"
      },
      "direction": "up"
    },
    {
      "label": "Ethereum",
      "delta": {
        "amount": "-2797.500000",
        "display": "-$2,797.50"
      },
      "cumulative": {
        "amount": "64357.500000",
        "display": "$64,357.50"
      },
      "direction": "down"
    },
    {
      "label": "Solana",
      "delta": {
        "amount": "1496.000000",
        "display": "$1,496.00"
      },
      "cumulative": {
        "amount": "65853.500000",
        "display": "$65,853.50"
      },
      "direction": "up"
    },
    {
      "label": "Chainlink",
      "delta": {
        "amount": "-662.500000",
        "display": "-$662.50"
      },
      "cumulative": {
        "amount": "65191.000000",
        "display": "$65,191.00"
      },
      "direction": "down"
    },
    {
      "label": "Dogecoin",
      "delta": {
        "amount": "-152.400000000000",
        "display": "-$152.40"
      },
      "cumulative": {
        "amount": "65038.600000000000",
        "display": "$65,038.60"
      },
      "direction": "down"
    }
  ],
  "annotations": [
    {
      "label": "Bitcoin",
      "text": "$10,230.00"
    },
    {
      "label": "Ethereum",
      "text": "-$2,797.50"
    },
    {
      "label": "Net",
      "text": "$8,113.60"
    }
  ]
}
```

## `holdings.allocation.v1`

> Allocation by holding: market value and portfolio weight per symbol, with a residual Other bucket for everything beyond top_n.

- **Frozen id:** `holdings.allocation.v1` · **digest:** `63d89e469006`
- **Payload type:** `HoldingsAllocationPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `top_n` | integer 1..20 | integer 1..20 | `5` | How many rows to render before the residual bucket. |
| `include_other` | boolean | true or false | `true` | Aggregate everything beyond `top_n` into an `Other` row. |
| `sort` | enum value_desc / value_asc / label | one of 'value_desc', 'value_asc', 'label' | `"value_desc"` | Row order: by value descending, ascending, or by label. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'holdings.allocation.v1' | default `"holdings.allocation.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `total` | object | required | `container` | — | — |
| `total.label` | string ≤64 chars | required | `text` | — | — |
| `total.amount` | object | required | `container` | — | — |
| `total.amount.amount` | decimal | required | `raw` | — | — |
| `total.amount.display` | string ≤32 chars | required | `display` | — | — |
| `categories` | array | required | `container` | empty | — |
| `categories[].label` | string ≤64 chars | required | `text` | — | — |
| `categories[].key` | string ≤32 chars | required | `text` | — | — |
| `categories[].value` | object | required | `container` | — | — |
| `categories[].value.amount` | decimal | required | `raw` | — | — |
| `categories[].value.display` | string ≤32 chars | required | `display` | — | — |
| `categories[].weight` | object | required | `container` | — | — |
| `categories[].weight.value` | decimal | required | `raw` | — | — |
| `categories[].weight.display` | string ≤16 chars | required | `display` | — | — |

### Example payload

```json
{
  "view": "holdings.allocation.v1",
  "title": "Allocation by holding",
  "total": {
    "label": "Total market value",
    "amount": {
      "amount": "65038.600000000000",
      "display": "$65,038.60"
    }
  },
  "categories": [
    {
      "label": "Bitcoin",
      "key": "BTC",
      "value": {
        "amount": "38550.000000",
        "display": "$38,550.00"
      },
      "weight": {
        "value": "0.5927249356535964796290203049",
        "display": "59.27%"
      }
    },
    {
      "label": "Ethereum",
      "key": "ETH",
      "value": {
        "amount": "15902.500000",
        "display": "$15,902.50"
      },
      "weight": {
        "value": "0.2445086456350536450661607107",
        "display": "24.45%"
      }
    },
    {
      "label": "Solana",
      "key": "SOL",
      "value": {
        "amount": "6096.000000",
        "display": "$6,096.00"
      },
      "weight": {
        "value": "0.09372895480530023708997426144",
        "display": "9.37%"
      }
    },
    {
      "label": "Chainlink",
      "key": "LINK",
      "value": {
        "amount": "2962.500000",
        "display": "$2,962.50"
      },
      "weight": {
        "value": "0.04554987345976081895981770825",
        "display": "4.55%"
      }
    },
    {
      "label": "Dogecoin",
      "key": "DOGE",
      "value": {
        "amount": "1527.600000000000",
        "display": "$1,527.60"
      },
      "weight": {
        "value": "0.02348759044628881925502701473",
        "display": "2.35%"
      }
    }
  ]
}
```

## `order.ticket.v1`

> Order ticket: a proposed buy or sell with its units, entry price and notional, plus the bounded inputs that re-render it. It places nothing.

- **Frozen id:** `order.ticket.v1` · **digest:** `0a2904b9b52d`
- **Payload type:** `OrderTicketPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** `symbol`, `side`

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `locale` | enum en-US / es-AR / de-DE | one of 'en-US', 'es-AR', 'de-DE' | `"en-US"` | Formatting locale for every rendered string. |
| `precision` | integer 0..8 | integer 0..8 | `2` | Decimal places for every figure this view renders. |
| `currency` | const 'USD' | only 'USD' | `"USD"` | Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted. |
| `symbol` | enum ADA / AVAX / BTC / DOGE / DOT / ETH / LINK / SOL | one of 'ADA', 'AVAX', 'BTC', 'DOGE', 'DOT', 'ETH', 'LINK', 'SOL' | `"BTC"` | Asset the order is written for, from the market reference. |
| `side` | enum buy / sell | one of 'buy', 'sell' | `"buy"` | Which way the order goes; `sell` disposes of units held. |
| `size` | string | string matching ^[0-9]{1,9}(\.[0-9]{1,8})?$ | `"1"` | How big the order is, as a decimal string (ADR-E D-5). |
| `size_in` | enum units / usd | one of 'units', 'usd' | `"units"` | What `size` counts: units of the asset, or US dollars. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'order.ticket.v1' | default `"order.ticket.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `symbol` | string ≤10 chars | required | `text` | — | input · one of 'ADA', 'AVAX', 'BTC', 'DOGE', 'DOT', 'ETH', 'LINK', 'SOL' |
| `name` | string ≤64 chars | required | `text` | — | — |
| `side` | enum buy / sell | required | `enum` | variant | input · one of 'buy', 'sell' |
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
| `inputs[].choices` | array ≤16 items | default `[]` | `container` | empty | — |
| `inputs[].pattern` | string ≤64 chars | default `null` | `text` | null | — |
| `effect` | const 'recalculate' | default `"recalculate"` | `constant` | — | — |
| `disclosure` | string ≤300 chars | required | `text` | — | — |

### Example payload

```json
{
  "view": "order.ticket.v1",
  "title": "Proposed order",
  "symbol": "BTC",
  "name": "Bitcoin",
  "side": "buy",
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
        "ADA",
        "AVAX",
        "BTC",
        "DOGE",
        "DOT",
        "ETH",
        "LINK",
        "SOL"
      ],
      "pattern": null
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
      "pattern": null
    },
    {
      "option": "size",
      "label": "Size",
      "control": "text",
      "value": "1",
      "choices": [],
      "pattern": "^[0-9]{1,9}(\\.[0-9]{1,8})?$"
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
      "pattern": null
    }
  ],
  "effect": "recalculate",
  "disclosure": "Illustrative ticket. This showcase has no broker and no execution: changing a field re-renders these figures, and nothing is ever sent, placed or settled."
}
```

## `payoff.curve.v1`

> Profit and loss of a proposed buy or sell across a bounded range of future prices, entry and break-even marked. An illustrative linear spot payoff, never an options payoff.

- **Frozen id:** `payoff.curve.v1` · **digest:** `205668c78931`
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
| `symbol` | enum ADA / AVAX / BTC / DOGE / DOT / ETH / LINK / SOL | one of 'ADA', 'AVAX', 'BTC', 'DOGE', 'DOT', 'ETH', 'LINK', 'SOL' | `"SOL"` | Asset the order is for. |
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
| `totals` | array | default `[]` | `container` | empty | — |
| `totals[].label` | string ≤64 chars | required | `text` | — | — |
| `totals[].amount` | object | required | `container` | — | — |
| `totals[].amount.amount` | decimal | required | `raw` | — | — |
| `totals[].amount.display` | string ≤32 chars | required | `display` | — | — |
| `series` | array | default `[]` | `container` | empty | — |
| `series[].name` | string ≤64 chars | required | `text` | — | — |
| `series[].points` | array | required | `container` | empty | — |
| `series[].points[].label` | string ≤64 chars | required | `text` | — | — |
| `series[].points[].value` | object | required | `container` | — | — |
| `series[].points[].value.amount` | decimal | required | `raw` | — | — |
| `series[].points[].value.display` | string ≤32 chars | required | `display` | — | — |
| `annotations` | array | default `[]` | `container` | empty | — |
| `annotations[].label` | string ≤64 chars | required | `text` | — | — |
| `annotations[].text` | string ≤200 chars | required | `text` | — | — |

### Example payload

```json
{
  "view": "payoff.curve.v1",
  "title": "Payoff across a price range: buy Solana",
  "disclosure": "Illustrative linear spot payoff on the demo portfolio's simulated prices: profit or loss is (price - entry) x quantity, with no fees, no slippage and no financing. There is no strike, no expiry, no implied volatility and no time decay behind this line. A sell is the mirror of the position and leaves no position to value.",
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
          "value": {
            "amount": "-150.0000000000000000000000000",
            "display": "-$150.00"
          }
        },
        {
          "label": "$110.49",
          "value": {
            "amount": "-137.5000000000000000000000000",
            "display": "-$137.50"
          }
        },
        {
          "label": "$114.30",
          "value": {
            "amount": "-125.0000000000000000000000000",
            "display": "-$125.00"
          }
        },
        {
          "label": "$118.11",
          "value": {
            "amount": "-112.5000000000000000000000000",
            "display": "-$112.50"
          }
        },
        {
          "label": "$121.92",
          "value": {
            "amount": "-99.99999999999999999999999999",
            "display": "-$100.00"
          }
        },
        {
          "label": "$125.73",
          "value": {
            "amount": "-87.49999999999999999999999999",
            "display": "-$87.50"
          }
        },
        {
          "label": "$129.54",
          "value": {
            "amount": "-74.99999999999999999999999999",
            "display": "-$75.00"
          }
        },
        {
          "label": "$133.35",
          "value": {
            "amount": "-62.49999999999999999999999999",
            "display": "-$62.50"
          }
        },
        {
          "label": "$137.16",
          "value": {
            "amount": "-49.99999999999999999999999999",
            "display": "-$50.00"
          }
        },
        {
          "label": "$140.97",
          "value": {
            "amount": "-37.49999999999999999999999999",
            "display": "-$37.50"
          }
        },
        {
          "label": "$144.78",
          "value": {
            "amount": "-25.00000000000000000000000000",
            "display": "-$25.00"
          }
        },
        {
          "label": "$148.59",
          "value": {
            "amount": "-12.50000000000000000000000000",
            "display": "-$12.50"
          }
        },
        {
          "label": "$152.40",
          "value": {
            "amount": "0E-30",
            "display": "$0.00"
          }
        },
        {
          "label": "$156.21",
          "value": {
            "amount": "12.50000000000000000000000000",
            "display": "$12.50"
          }
        },
        {
          "label": "$160.02",
          "value": {
            "amount": "25.00000000000000000000000000",
            "display": "$25.00"
          }
        },
        {
          "label": "$163.83",
          "value": {
            "amount": "37.49999999999999999999999999",
            "display": "$37.50"
          }
        },
        {
          "label": "$167.64",
          "value": {
            "amount": "49.99999999999999999999999999",
            "display": "$50.00"
          }
        },
        {
          "label": "$171.45",
          "value": {
            "amount": "62.49999999999999999999999999",
            "display": "$62.50"
          }
        },
        {
          "label": "$175.26",
          "value": {
            "amount": "74.99999999999999999999999999",
            "display": "$75.00"
          }
        },
        {
          "label": "$179.07",
          "value": {
            "amount": "87.49999999999999999999999999",
            "display": "$87.50"
          }
        },
        {
          "label": "$182.88",
          "value": {
            "amount": "99.99999999999999999999999999",
            "display": "$100.00"
          }
        },
        {
          "label": "$186.69",
          "value": {
            "amount": "112.5000000000000000000000000",
            "display": "$112.50"
          }
        },
        {
          "label": "$190.50",
          "value": {
            "amount": "125.0000000000000000000000000",
            "display": "$125.00"
          }
        },
        {
          "label": "$194.31",
          "value": {
            "amount": "137.5000000000000000000000000",
            "display": "$137.50"
          }
        },
        {
          "label": "$198.12",
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

## `scenario.comparison.v1`

> The same proposed sale costed under each lot-selection method, so the realised result and the short/long split can be compared side by side. It recommends no method.

- **Frozen id:** `scenario.comparison.v1` · **digest:** `d996313186c4`
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

### Example payload

```json
{
  "view": "scenario.comparison.v1",
  "title": "Same sale, different lot method",
  "subject": {
    "label": "Bitcoin",
    "symbol": "BTC",
    "quantity_display": "0.18",
    "price": {
      "amount": "64250.00",
      "display": "$64,250.00"
    },
    "proceeds": {
      "amount": "11565.000000",
      "display": "$11,565.00"
    }
  },
  "columns": [
    {
      "method": "FIFO",
      "label": "FIFO \u2014 oldest lots first",
      "cost_basis": {
        "amount": "7740.00",
        "display": "$7,740.00"
      },
      "realized_pl": {
        "amount": "3825.000000",
        "display": "+$3,825.00"
      },
      "short_term_pl": {
        "amount": "0",
        "display": "$0.00"
      },
      "long_term_pl": {
        "amount": "3825.000000",
        "display": "+$3,825.00"
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
        "amount": "10260.00",
        "display": "$10,260.00"
      },
      "realized_pl": {
        "amount": "1305.000000",
        "display": "+$1,305.00"
      },
      "short_term_pl": {
        "amount": "1305.000000",
        "display": "+$1,305.00"
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
        "amount": "10260.00",
        "display": "$10,260.00"
      },
      "realized_pl": {
        "amount": "1305.000000",
        "display": "+$1,305.00"
      },
      "short_term_pl": {
        "amount": "1305.000000",
        "display": "+$1,305.00"
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
      "amount": "2520.000000",
      "display": "$2,520.00"
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

- **Frozen id:** `taxlots.table.v1` · **digest:** `dfc041e6746d`
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
| `quantity` | string | string matching ^\d{1,12}(\.\d{1,8})?$ | `"0.5"` | Units to sell, written as a decimal string ('0.5'). A dollar-sized ask is resolved to units by the `simulate_sale` tool; copy the units it returned rather than dividing (spec 0015 OD-4). |
| `lot_method` | enum FIFO / LIFO / HIFO | one of 'FIFO', 'LIFO', 'HIFO' | `"FIFO"` | Which lots the sale consumes first: FIFO the oldest, LIFO the newest, HIFO the dearest. |

### Field inventory

| Field | Type / format | Presence | Binding | State | Input |
|---|---|---|---|---|---|
| `view` | const 'taxlots.table.v1' | default `"taxlots.table.v1"` | `constant` | — | — |
| `title` | string ≤120 chars | required | `text` | — | — |
| `subtitle` | string ≤200 chars | required | `text` | — | — |
| `price` | object | required | `container` | — | — |
| `price.label` | string ≤64 chars | required | `text` | — | — |
| `price.amount` | object | required | `container` | — | — |
| `price.amount.amount` | decimal | required | `raw` | — | — |
| `price.amount.display` | string ≤32 chars | required | `display` | — | — |
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
| `lots[].term` | enum short / long | required | `enum` | variant | — |
| `lots[].units` | string ≤32 chars | required | `text` | — | — |
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
| `remaining` | array | default `[]` | `container` | empty | — |
| `remaining[].label` | string ≤64 chars | required | `text` | — | — |
| `remaining[].text` | string ≤200 chars | required | `text` | — | — |

### Example payload

```json
{
  "view": "taxlots.table.v1",
  "title": "Tax lots this sale consumes",
  "subtitle": "Sell 0.5 BTC under FIFO",
  "price": {
    "label": "Price",
    "amount": {
      "amount": "64250.00",
      "display": "$64,250.00"
    }
  },
  "proceeds": {
    "label": "Proceeds",
    "amount": {
      "amount": "32125.000000",
      "display": "$32,125.00"
    }
  },
  "cost_basis": {
    "label": "Cost basis",
    "amount": {
      "amount": "22620.00",
      "display": "$22,620.00"
    }
  },
  "realized": {
    "label": "Realised P/L",
    "amount": {
      "amount": "9505.000000",
      "display": "+$9,505.00"
    }
  },
  "by_term": [
    {
      "label": "Short-term",
      "term": "short",
      "lots": 1,
      "realized": {
        "amount": "580.000000",
        "display": "+$580.00"
      }
    },
    {
      "label": "Long-term",
      "term": "long",
      "lots": 1,
      "realized": {
        "amount": "8925.000000",
        "display": "+$8,925.00"
      }
    }
  ],
  "lots": [
    {
      "label": "lot-btc-01",
      "acquired_on": "2025-01-13",
      "term": "long",
      "units": "0.42",
      "cost_basis": {
        "amount": "18060.00",
        "display": "$18,060.00"
      },
      "proceeds": {
        "amount": "26985.000000",
        "display": "$26,985.00"
      },
      "gain_loss": {
        "amount": "8925.000000",
        "display": "+$8,925.00"
      },
      "trend": "up",
      "fully_sold": true
    },
    {
      "label": "lot-btc-02",
      "acquired_on": "2025-01-17",
      "term": "short",
      "units": "0.08",
      "cost_basis": {
        "amount": "4560.00",
        "display": "$4,560.00"
      },
      "proceeds": {
        "amount": "5140.000000",
        "display": "$5,140.00"
      },
      "gain_loss": {
        "amount": "580.000000",
        "display": "+$580.00"
      },
      "trend": "up",
      "fully_sold": false
    }
  ],
  "remaining": [
    {
      "label": "Units left",
      "text": "0.1"
    },
    {
      "label": "Cost basis",
      "text": "$5,700.00"
    },
    {
      "label": "Market value",
      "text": "$6,425.00"
    },
    {
      "label": "Open lots",
      "text": "1"
    }
  ]
}
```
