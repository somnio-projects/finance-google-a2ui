---
description: The client half of ADR-K — the client binds the backend's DTOs and transforms nothing. What a reviewer rejects, with the accepted form beside it. Loads when touching client views, blocs or repositories.
paths:
  - "client_flutter/*/lib/**/view/**/*.dart"
  - "client_flutter/*/lib/**/widgets/**/*.dart"
  - "client_flutter/*/lib/**/bloc/**/*.dart"
  - "client_flutter/*/lib/**/repository/**/*.dart"
alwaysApply: false
---

# Client presentation rules — bind, do not transform

The other half of [ADR-K](../../../docs/adr/ADR-K-response-shaping.md). The
backend's [`presentation.md`](../backend/presentation.md) says everything the
client renders is shaped server-side. This file says what that obliges the
client to *not* do, in terms a reviewer can act on.

> **The invariant.** The backend ships a payload that is already the widget's
> shape, with every number already a string. The client's whole job is to put
> those values on screen. **Any Dart that turns a payload value into a
> different value is a defect**, however small, however obviously correct.

This is not a style preference. It is the thing the showcase exists to
demonstrate ([ADR-E](../../../docs/adr/ADR-E-money-representation.md),
numbers-from-tools): finance arithmetic lives in one tested place, and that
place is not Dart.

## 1. The five bans, and the reviewer's test for each

### Never format a number

A reviewer rejects any `toStringAsFixed`, `NumberFormat`, `intl`
currency/percent/compact formatter, `DateFormat`, manual `'\$$value'`
interpolation, thousands-separator helper, or rounding applied to a value that
came from the backend.

```dart
// ✗ rejected
Text('\$${holding.marketValue.toStringAsFixed(2)}')
// ✓ accepted — the backend already produced the string
Text(holding.marketValueDisplay)
```

**The test:** search the diff for `toStringAsFixed`, `NumberFormat`,
`DateFormat`, `.round(`, `.toPrecision`, `%`. Every hit on a payload value is a
change request. (`intl` is not currently a dependency of `app/`. Adding it in
order to format a backend figure is the same defect, one step earlier.)

### Never compute a figure

A reviewer rejects arithmetic — `+ - * /`, `reduce`, `fold`, `sum`, a
percentage, a difference, a ratio, a total — over values that arrived from the
backend.

```dart
// ✗ rejected — a total the backend did not send
final total = holdings.fold<double>(0, (a, h) => a + h.value);
// ✓ accepted — ask for the projection that carries the total
Text(allocation.totalDisplay)
```

**The test:** any arithmetic operator whose operands trace back to a response
is a change request. Arithmetic over *layout* values — a `SizedBox` height, a
flex weight, an animation curve — is fine and is not what this bans.

### Never derive a field

A reviewer rejects a value the payload does not contain being manufactured from
values it does: a label chosen by comparing two numbers, a colour picked from
the sign of a figure the client computed, a "since inception" window inferred
from two dates, a sort order the backend did not send.

```dart
// ✗ rejected — the client decided what "gain" means
final isGain = double.parse(row.change) > 0;
// ✓ accepted — the backend declares the trend; the client maps it to a token
final color = switch (row.trend) {
  Trend.up => tokens.gain,
  Trend.down => tokens.loss,
  Trend.flat => tokens.neutral,
};
```

Mapping a **declared enum** to a theme token is binding, not deriving — the
backend made the judgement, the client chose the paint. Parsing a display
string back into a number in order to make that judgement is the defect, and it
is the most common form this ban takes.

**The test:** `double.parse`, `int.parse`, `num.tryParse` applied to anything
that came from the wire. The backend sends `*Display` strings *and* raw values
where a widget needs to plot; if a widget needs a number the payload does not
carry, the payload is wrong, not the widget.

### Never interpret a template

A reviewer rejects any client-side interpretation of a field path, an
expression, a format string or a layout descriptor supplied by the server or
the model — ADR-K D-3 forbids exactly this, and it forbids it on both ends.
A2UI surfaces arrive already composed; the client renders the component the
catalog declares, it does not evaluate instructions carried inside a payload.

**The test:** any `switch` or map lookup keyed on a **free-form** string from
the wire that then builds different widget trees. Keyed on a **declared,
versioned** `view` id or a declared enum: fine. Keyed on whatever the server
happened to put in a `type` field: not fine.

### Never invent a view id

View ids are `<component>.<variant>.v<N>` and they come from the backend's
catalog, `GET /v1/views` (ADR-K D-8). A reviewer rejects an id assembled by
string concatenation, an id guessed from a component name, and an id sent that
the catalog does not list.

```dart
// ✗ rejected — a string the catalog has never heard of
'?view=${component}.${variant}.v1'
// ✓ accepted — a constant copied from the catalog, one per view the client binds
static const attributionWaterfall = 'attribution.waterfall.v1';
```

**The test:** any `view` value built at runtime. Ids the client uses are
compile-time constants; the catalog is what proves they exist.

## 2. What the client does instead

| Need | Where it is met |
|---|---|
| A figure in a different unit, precision or locale | a **declared option** on the projection (`precision`, `locale`, `currency`) — the backend renders it |
| A field the widget needs and the payload lacks | a change to the projection, backend-side; `fields` trims, it does not add |
| A different arrangement of the same data | a **different registered view**, selected by id |
| A view that does not exist yet | a new projection in the backend — which, by ADR-K D-15, edits no existing file and appears automatically in `/v1/views` |

In every row the answer is a backend change. That is the accepted cost recorded
in ADR-K's *Consequences*, not an obstacle to route around. **"I'll just map it
in the client for now" is the exact failure this ADR was written to prevent**,
and it is a change request even when the mapping is one line and obviously
correct — because the next one will be three lines and subtly wrong, in a
language with no tests for finance arithmetic and no `Decimal`.

## 3. Two error shapes, and the client parses both

Worth stating because it is not guessable from either side alone
([ADR-J](../../../docs/adr/ADR-J-rest-api-and-a2a-surface.md) D-3, and the
module docstring of `backend/src/app/api/a2a.py`):

| Surface | Failure shape |
|---|---|
| `/v1/**` | RFC 9457 `application/problem+json` — `type`, `title`, `detail`, `instance`, `request_id` |
| the A2A root (JSON-RPC) | a JSON-RPC **error object with HTTP 200** |
| a failure *before* the A2A envelope is parsed | an HTTP-level problem document, on the JSON-RPC surface |

So a repository talking to the A2A surface cannot treat HTTP 200 as success,
and cannot assume a failure there is a problem document. It must handle both.
The `detail` of a problem document is safe to show to a user by contract —
the backend guarantees it carries no stack trace, SQL or library text — but it
is still English prose from the server, not a formatted figure.

`input_required` is a **normal terminal task state**, not an error
([ADR-D](../../../docs/adr/ADR-D-a2ui-streaming-transport.md) D-3): a surface
is waiting for the user. A client that renders it as a failure is wrong.

## 4. What is enforced

**Nothing in this file is enforced by a machine.** `dart analyze` cannot see
the difference between formatting a layout value and formatting a market value,
and the client gate (`dart.format`, `dart.analyze`, `client.tokens`,
`client.config`, `flutter.test`, `flutter.web` — all landing with GGU-1, PR #30)
contains no check for any of it.

This is the rule set's weakest point and it is better said than hidden. Two
things carry it in the meantime: the greps named under each ban above, which a
reviewer can run on a diff in seconds, and the widget tests required by
[`testing.md`](testing.md) §4, which assert that a rendered string is the
payload's string **verbatim** — a test that fails the moment anyone formats
anything.

A `client.presentation` grep gate over `toStringAsFixed|NumberFormat|DateFormat|double\.parse`
in `lib/**` would close most of it. It is not added here because
`.claude/ship-gate.json` is owned by GGU-1 (PR #30); it is the obvious next
entry after `client.tokens` and `client.config`, which prove the pattern works.
