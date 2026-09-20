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
  leaf whose containing object also declares a numeric leaf: the `*Display`
  pair of [ADR-E](../adr/ADR-E-money-representation.md) D-2, `{amount,
  display}` or `{value, display}`.
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

## `attribution.waterfall.v1`

> Unrealised profit and loss walked from cost basis to market value, one bucket per holding, biggest move first.

- **Frozen id:** `attribution.waterfall.v1` · **digest:** `e866358af26d`
- **Payload type:** `AttributionWaterfallPayload`
- **Served by:** `GET /v1/portfolios/{portfolio_id}/views` · `POST /v1/view-renders`
- **Editable fields:** read-only

### Options

| Option | Type / format | Accepts | Default | Description |
|---|---|---|---|---|
| `fields` | array ≤8 items | list of names | `null` | Sections to render; omit for all of them. A section this view does not offer is rejected, never ignored. |
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
