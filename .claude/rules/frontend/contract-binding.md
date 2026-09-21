---
description: How the frontend/ client binds backend payloads — the numbers rule, the fifteen prohibitions, view ids, options, ETags. Loads when touching components, the repository layer or the transport.
paths:
  - "frontend/app/lib/components/**"
  - "frontend/packages/finance_views_repository/**"
  - "frontend/packages/finance_api_client/**"
  - "frontend/app/test/components/**"
alwaysApply: false
---

# Contract-binding rules

Enforces [ADR-K](../../../docs/adr/ADR-K-response-shaping.md) and
[ADR-E](../../../docs/adr/ADR-E-money-representation.md) on the client side.
The normative source is
[`specs/client/0003-client-backend-contract.md`](../../../specs/client/0003-client-backend-contract.md)
— fifteen numbered prohibitions, N-1 to N-15. This file is what a reviewer
checks against; the spec is what it means.

**One line:** *the backend shapes every payload; the client binds it.* If a
Dart file needs `NumberFormat`, `dart:math` or a `fold` over a payload list to
put something on screen, it is wrong.

## 1. The numbers rule is absolute, and it is a test

`app/test/architecture/binding_rules_test.dart` fails on twelve mechanisms:
`NumberFormat`, `package:intl`, `dart:math`, `toStringAsFixed`,
`toStringAsPrecision`, `toStringAsExponential`, and **both** the `parse` and
`tryParse` spelling of `double`, `num` and `int`. `double.parse` does not
match `double.tryParse` as a substring, and the `try*` form is the one a
developer reaches for first — listing only one would have been a rule with
a hole in it. Clock reads (`DateTime.now(`, `DateTime.timestamp(`,
`Stopwatch(`) fail the same way.

`ViewPayload` deliberately exposes **no raw map**: a `json` getter would have
let `payload.json['total']['amount']` reach a `Decimal` with nothing stopping
arithmetic on it. It was removed for that reason — do not add it back.

It exposes exactly **one** numeric accessor, `geometry(path)`, and that is a
GGU-55 amendment to a rule that used to say "none" (ADR-L D-14). The contract
keeps a raw `amount` beside every `*Display` string *so that a chart can be
drawn from it* — N-4 below says so — and the value-to-pixel mapping cannot
live on a server that does not know the width the client will be laid out in.
`geometry` is implemented in `packages/finance_views_repository/lib/src/raw_decimal.dart`,
which is the only file allow-listed for a number mechanism, by path, in the
same way `jsonDecode` is allow-listed in the transport. It is **not exported
from the package barrel**, so `ViewPayload.geometry` is its only caller. Two
tests hold it: one allows that path, and `::the geometry seam is the only
exemption` asserts the allow set has exactly one member and still names a
file that exists.

**What `geometry` is for:** a position on a canvas. It never reaches a `Text`,
is never re-formatted, and never becomes a figure a human reads. If you are
reaching for it to *show* something, you want a `*.display` string, and if the
payload has none, N-3 applies — raise it.

- **N-1** Never format a number. No currency symbol, no thousands separator, no percent sign, no `+`/`−` prefix. Every figure already arrives as a `*Display` string.
- **N-2** Never compute a figure. No sums, differences, percentages, running totals, break-evens, weights or spreads. `cumulative`, `spread`, `by_term` and `markers` are all supplied.
- **N-3** Never derive a field. If a value must appear and only a `raw` member carries it, **the payload is missing a field — raise it.** `ViewPayload` throws `PayloadContractException` naming the path, and `ComponentHost` renders it, precisely so this is impossible to ignore.
- **N-4** Never print a raw figure. `amount`, `value` and `units` exist for chart geometry. `"0.5927249356535964796290203049"` must never reach a user.
- **N-13** Never read the device clock for `as_of`. It travels in the envelope, as a string, and is not re-formatted.
- **N-15** Never send a float where a decimal string is declared. `"0.25"`, not `0.25`.

The sign is **baked into** the display string (`"+$3,825.00"`). Do not prepend
one, and do not choose a colour by parsing the string — use the supplied
`direction` enum, or the sign of the raw value.

## 2. View ids and options come from the catalog

- **N-6** Only ids from `GET /v1/views` may be sent. A view id is a literal in **one** place: the component that serves it, or the page that requests it. Never guessed, never assembled from parts.
- **N-7** Only options a view's `options_schema` declares. Anything else is a 422 for the *whole* request — the read endpoint applies one flat option set to every requested view, so an option only one of them declares fails all of them.
- **N-8** Do not re-validate a server bound. Use the `pattern`, `choices` and ranges the server sent; do not add a stricter client rule beside them.
- **N-10** Do not reorder, filter or re-rank rows. `sort`, `top_n`, `methods` and `lot_method` are **options**, not client behaviour. Rows render in the order they arrived.
- At most `ViewsRepository.maxViewsPerRequest` (4) ids per read; the repository rejects more before spending a round trip. **The catalog has six components**, so a screen wanting all of them exceeds one request: `views_batch.dart` chunks the ids and the caller issues one request per chunk (GGU-69). Do not raise the constant to dodge that — it mirrors the server's `MAX_VIEWS`.

## 3. Rendering

- **N-9** Never drop a disclosure or a note. `disclosure`, `notes[]` and server-written `label`/`text` are compliance statements and are rendered verbatim.
- **N-5** Never interpret a template. No expression, format string or field path from the server is evaluated. `ViewPayload` paths are literals written by a component's author, and `binding_rules_test.dart` enforces both halves: `::nothing interprets a server-supplied string` bans `dart:mirrors`, `Function.apply` and `jsonDecode` outside the transport, and `::payload paths are literals, never variables` rejects `payload.text(someVariable)`. This is a security rule (`frontend/SECURITY.md`).
- A view id with no registered component is **not an error** — `ComponentHost` shows a placeholder and the other surfaces still render. The catalog grows on its own schedule.
- No payload carries an `isLoading` flag. Loading and failure are **transport** states and live in bloc state, never in a payload.

## 4. Transport

- The credential goes in the `Authorization` header and nowhere else (**N-14**). Never a URL, a query string or a log line.
- A **304 is a success**: the repository resolves it to the cached envelope. It is not an error and not an empty result. `ETag` values are echoed back verbatim — the quotes are part of the tag.
- Errors are RFC 9457. Branch on `ProblemDetails.code` (the `type` suffix), **never** on `detail`, which is prose that may be reworded.
- A non-problem error body (a gateway's HTML) becomes a `TransportFailure`. Never synthesise a problem document the backend did not send.
- `auth/revoked-token` **does not exist** — the backend cannot emit it (spec `client/0003` OD-3). Do not write a branch for it.

## 5. Adding a component — the checklist

- [ ] Field paths taken from the view's entry in the backend's generated catalog, not from a screenshot or from memory.
- [ ] Every figure bound from a `*.display` string; no raw member reaches a `Text`.
- [ ] Rows rendered in arrival order; no client-side sort or filter.
- [ ] Disclosures and notes rendered verbatim.
- [ ] A test asserting the display strings appear **and** that the raw values do not.
- [ ] A test for the missing-field path (the component raises, the host shows it).
- [ ] Field paths taken from `docs/catalog/view-catalog.snapshot.json` — and, for a component test, **read from it** through `app/test/helpers/catalog_snapshot.dart` rather than copied.
- [ ] A raw member is read only through `geometry`, and only for a coordinate.
- [ ] The PR body states which of N-1…N-15 the change was checked against (spec `client/0003` AC-18).
