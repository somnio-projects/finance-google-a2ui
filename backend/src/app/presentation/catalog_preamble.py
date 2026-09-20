"""The normative prose at the head of the generated contract (GGU-41).

It lives in its own module because it is the one part of the document a human
writes: what "frozen" means, and how every column is derived. Keeping it beside
the renderer rather than in a template file keeps the presentation layer free
of I/O (ADR-K D-6) and keeps both files inside the line budget.

The prose is written as wrapped bullet lists rather than Markdown tables: a
table row cannot be broken, and an unbreakable 200-character row inside a
Python string is a line-length violation with nowhere to go.
"""

from typing import Final

SPEC_LINK: Final[str] = (
    "[`specs/backend/0019-frozen-catalog-contract.md`]"
    "(../../specs/backend/0019-frozen-catalog-contract.md)"
)

PREAMBLE: Final[str] = f"""# Frozen catalog contract

<!-- GENERATED FILE — do not edit by hand.
     Regenerate with: cd backend && make catalog -->

**Source of truth:** the projection registry in `backend/src/app/presentation/`,
under [ADR-K](../adr/ADR-K-response-shaping.md) D-14.
**Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) ·
**Spec:** {SPEC_LINK}

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
  pair of [ADR-E](../adr/ADR-E-money-representation.md) D-2, `{{amount,
  display}}` or `{{value, display}}`.
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
"""

__all__ = ["PREAMBLE", "SPEC_LINK"]
