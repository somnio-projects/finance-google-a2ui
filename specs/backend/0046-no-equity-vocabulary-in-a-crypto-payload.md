# 0046 — No equity vocabulary in a crypto payload

- **Area:** backend (domain, presentation, the agent's draft-order tool, the scripted answer) → both generated catalog artefacts → the Flutter bindings that read the renamed fields
- **Status:** In progress
- **Tickets:** GGU-122 (the void total and the vocabulary sweep), GGU-123 (`attribution.driver.v1`'s `shares`), GGU-119 (`buckets[].delta_label` and the orphaned `selected_label`)
- **Follows:** [backend/0044](0044-the-portfolio-is-crypto.md) — this is the part of it that a ticker grep could not see
- **Also:** [backend/0031](0031-order-ticket-v2.md) (the draft order and its impact panel), [backend/0032](0032-the-attribution-card.md) (the waterfall headline and the driver card), [backend/0039](0039-the-surface-answers-the-question-that-was-asked.md) (`attribution.window.v1`), [frontend/0028](../frontend/0028-the-waterfall-matches-the-ui-kit.md) §6 (BG-1, BG-4), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

Spec 0044 turned the demo portfolio into a crypto portfolio: the seed, the
taxonomy, the tickers, the names, the prose the model copies. It did not turn
over the **words the payloads write down**, and three different kinds of
equity framing survived it.

They survived because none of them is a ticker, and the sweep that checked
0044's work looked for tickers.

| view | field | what ships today | what it is |
|---|---|---|---|
| `holdings.positions.v1` | `positions[].detail`, **every row** | `2.1 sh · avg $41,698.00` | an abbreviation inside a composed sentence |
| `attribution.waterfall.v1` | `buckets[].detail`, **every bucket** | `+54.08% · 2.1 sh · $64,250.00` | the same, on the card GGU-115 has just restyled |
| `attribution.driver.v1` | `shares.label`, and the **field name** `shares` | `Shares`, holding 2.1 Bitcoin | a label *and* a contract field name |
| `order.ticket.v2` | `impact.units` | `{"label": "Est. shares", "units": "17.05"}` | a label on top of a number that means nothing |

The last one is not a vocabulary problem with a number attached; it is two
problems that happen to share a field.

**`impact.units` is void, not imprecise.** It is the arithmetic sum of every
leg's quantity: `0.05 BTC + 1.0 ETH + 16 SOL = 17.05`. Quantities of different
assets are not commensurable, so there is no value this field could hold that
would be right — the question it answers does not exist. It sits beside a money
total that *is* correct (`$3,212.50 + $3,480.00 + $2,438.40 = $9,130.90`,
verified live), which is what makes it read as trustworthy.

**And the demo puts three of the four on screen.** `holdings.positions.v1` is
the Holdings tab; `attribution.waterfall.v1` is Flow A's card; `order.ticket.v2`
is Flow C's ticket with a stepper inviting the viewer to change it.

Two adjacent gaps in the same payloads are folded in here because they are the
same edit to the same modules (GGU-119): a bucket has **no caption** for its
contribution, and it carries a `selected_label` **nothing draws**.

## 2. Scope

**In.** `app.domain.draft_impact`; `app.presentation`'s
`positions_payload`/`positions_rows`, `attribution_payload`/`attribution_walk`,
`window_payload`/`window_walk`, `driver_payload`/`driver_figures`,
`order_ticket_v2_payload`/`_build`/`_lines`, and
`views/attribution_driver.py`'s A2UI adapter; the `draft_order` tool's
description and its `impact_block`; the scripted Flow C answer in
`infra/model/demo_script.py`; both generated catalog artefacts; the Dart
bindings and tests for the three renamed or removed fields.

**Out.** Any new projection, endpoint or component. How any figure is computed,
rounded or formatted — ADR-E is untouched, and no arithmetic changes. The
`day_share` framing (OD-5). `order.ticket.v1`, which states a single asset's
units and is therefore not affected. Component **layout** on the waterfall and
the tax-lot table: GGU-115 and GGU-116 own those, and this spec only adds a
string those cards were already leaving a hole for.

## 3. Rulings

- **OD-1 — a composed `detail` line counts the asset in the asset's own
  units.** `2.1 BTC · avg $41,698.00`, not `2.1 sh`, and not `2.1 units`.

  `detail` is a **sentence**, so removing a word is not a deletion — something
  has to stand where `sh` stood, and the choice is a product decision rather
  than a cleanup. Three candidates were on the table:

  1. **drop the unit word** — `2.1 · avg $41,698.00`. Rejected: the second line
     is the only place the row says what the number counts. A bare `2.1` beside
     a price is worse than a wrong unit, because it is ambiguous rather than
     merely false.
  2. **a generic noun** — `2.1 units · avg $41,698.00`. Rejected: it is true and
     it is empty. "Units" is the word a system uses when it does not know what
     it is holding, and this payload does know.
  3. **the asset's own ticker** — `2.1 BTC · avg $41,698.00`. **Chosen.** It is
     the honest unit word — a quantity of Bitcoin has no unit but Bitcoin — it
     is already in the payload (`symbol`), it needs no new field, and it reads
     the way an exchange reads.

  The cost, recorded rather than hidden: the ticker now appears **twice** on a
  Holdings row, once in the chip and once in this line. That is redundancy, not
  error, and the alternative is ambiguity. Design may later want the chip or
  this line to change; the string is the backend's either way.

  The same ruling applies to `attribution.waterfall.v1`'s
  `buckets[].detail` — `+54.08% · 2.1 BTC · $64,250.00` — because it is the
  same sentence about the same quantity.

  **The settlement fund follows the rule rather than an exception.** USDC's
  waterfall step reads `0.00% · 51764 USDC · $1.00`. `holdings.positions.v1`
  gives cash its own written caption already and is untouched there.

- **OD-2 — `order.ticket.v2`'s `impact.units` is removed, not relabelled, and
  so is the domain statement behind it.** A better label on a void number is a
  better-dressed void number. `DraftImpact.units` leaves
  `app.domain.draft_impact`, `UnitTotal` leaves
  `order_ticket_v2_lines`, `unitsDisplay` leaves the tool's `impact_block`, and
  the scripted Flow C answer stops reading it aloud.

  **Nothing replaces it, and that is the ruling.** GGU-122 AC-1 allowed a leg
  count as a substitute; the header already states the leg count, and each
  `lines[]` entry already carries its own quantity in its own asset, so a
  fourth figure in the panel would be a third statement of something stated
  twice. The panel is money-only: total, fees, cash remaining, weight shifts.

  Removing it from the **domain** rather than only from the presenter is the
  load-bearing half. A statement left on `DraftImpact` is a statement the next
  consumer prints, and this one had two consumers already (the projection and
  the agent tool). ADR-K D-6 puts financial statements in the domain; the
  corollary is that a statement which is not true does not get to live there.

- **OD-3 — `attribution.driver.v1`'s `shares` becomes `holding`, and its label
  is served per asset: `BTC held`.** Both halves of GGU-123's finding are
  equity framing, and they fail differently: the **label** is what a viewer
  reads, the **field name** is what a client binds. Renaming only the label
  would leave `"shares": {"label": "BTC held"}` in the frozen contract, which is
  worse than either consistent state.

  The label is `HOLDING_LABEL = "{symbol} held"`, filled from the payload's own
  `symbol` — a **template rather than a noun**, because the honest unit word is
  per asset and a single hard-coded noun would be the "units" mistake from OD-1
  in a second place. It stays a server-written string under N-9: a client
  composing `'$symbol held'` would not follow the view's `locale` option.

  This is client-breaking by construction, so the projection, the A2UI adapter,
  both catalog artefacts and the Dart binding move in **one** release — which
  is the whole reason GGU-123 is a ticket instead of a quiet rename.

- **OD-4 — `buckets[].selected_label` is replaced by `buckets[].delta_label`,
  on both walks, in one edit.** GGU-119's two halves are one field slot.

  `delta_label` **arrives** because the kit's detail frame reads *Contribution
  +$2,980* and the payload sent the figure with no word in front of it. A Dart
  constant `'Contribution'` would not follow the view's `locale` option — the
  ruling `presentation.md` already records for `cost_basis` and `proceeds`: **a
  `label` is a binding.**

  `selected_label` **leaves** because frontend/0028 OD-1 keeps the net figure in
  the card header, which left that caption with no place in the frame. It was
  bound by `attribution_waterfall_reader.dart` and drawn by nothing. A field
  nobody draws is a field nobody maintains.

  **Both walks, because one reader binds both.** `attribution.window.v1`
  carries the same field and `AttributionWindowComponent` reuses
  `readWaterfall` verbatim, so changing one payload and not the other would
  break the other view at the transport. GGU-119 names only the waterfall; the
  window is in scope as a consequence of the client's own reuse, not as scope
  creep.

- **OD-5 — `day_share`'s 216.58 % is left exactly as it is, and this spec
  records that it waits on design.** GGU-123 §2 observed *Of day gain: 216.58%*
  with the caption *of +$2,201.05*.

  **The arithmetic is right.** `4,767.00 / 2,201.05 = 2.1658`, and it exceeds
  100 % *because other assets lost money that day*, so one winner can be more
  than the net. Nothing here is a numbers defect.

  It is a **framing** question with at least three answers — a denominator
  caption ("of the net, after $X of losses"), a different denominator (gross
  gains), or suppression above 100 % — and choosing among them is design's call,
  not this ticket's. Recorded here so the next reader does not rediscover it as
  a bug.

  **It must never be capped, clamped or rescaled, least of all in Dart.** That
  would be computing a financial figure in the client (N-1) and would replace a
  surprising true number with a comfortable false one. Whatever design chooses
  arrives from the backend, formatted (N-9).

- **OD-6 — the vocabulary check renders every registered view; it does not grep
  the source and it does not call the API.** `tests/unit/presentation/test_asset_vocabulary.py`.

  This is the ruling with the most history behind it, and all of it is
  `.claude/rules/ci-conventions.md` §5 question 2 — *does the command cover what
  its name claims?* Two sweeps reported **clean** before this one:

  | sweep | reported | was actually |
  |---|---|---|
  | over the live API | 0 hits across 12 views | every request carried an option the view does not declare, so all twelve answered **422** and it was counting matches in *error bodies* |
  | `shares?\|stocks?\|equity\|dividends?\|ticker` | `holdings.positions.v1` and `attribution.waterfall.v1` clean | `sh` is not in that pattern, and every row of both carried it |

  So the check is built to fail rather than to pass:

  - **It renders.** `Projection.example` is a real render over the sample
    portfolio at declared defaults (`presentation/spec.py`), so a 422 cannot be
    mistaken for a payload.
  - **It walks keys as well as values**, because a *field name* is part of the
    contract — that is how `attribution.driver.v1`'s `shares` is caught.
  - **The pattern includes abbreviations** — `sh` and its plural — as **whole**
    words. `_` is a word character, so `day_share` is correctly not a hit and a
    field literally named `shares` is. The plural is spelt `sh(?:s)?` rather
    than with a bare `s?`, in the pattern *and* in this sentence, because
    codespell reads the three-letter form as a misspelling of `ssh` and
    `repo.spelling` is a repo-wide gate one view's test has no business
    weakening for itself. The inline `# codespell:ignore` directive does not
    work under the gate's invocation; do not reach for it.
  - **It reports the field path, not a boolean**, because `detail` is a composed
    sentence and the fix differs per field.
  - **It cannot pass vacuously**, three ways: the set of views it rendered is
    compared against `tests.catalog.SHIPPED_VIEWS` (written down *outside* the
    registry), a floor is asserted on the number of strings walked, and a fourth
    test shows the scanner **rejecting** planted copies of all four live
    findings. A check never seen to reject is the same defect one level up.

  It was **shown failing on today's payloads before the fix** — 16 hits across
  exactly the four views GGU-122 names — and that output is in the pull request.

## 4. Acceptance criteria

1. **AC-1** (GGU-122 AC-1) — `order.ticket.v2`'s impact panel presents no
   cross-asset quantity, and `DraftImpact` states none.
2. **AC-2** (GGU-122 AC-2, GGU-123 AC-2) — one test renders **every** registered
   view and asserts no equity vocabulary, abbreviations included, reporting field
   paths; shown failing first; anti-vacuous. There is no second such test.
3. **AC-3** (GGU-122 AC-3, GGU-123 AC-1) — every renamed or removed field's
   client binding moves in this release: `impact.units`, `shares.*`,
   `selected_label`.
4. **AC-4** — `buckets[].delta_label` is served by both walks and **drawn** by
   the callout and the detail strip.
5. **AC-5** (GGU-123 AC-3) — the `day_share` framing is recorded as design's
   open question (OD-5), unchanged and uncapped.
6. **AC-6** — `make catalog` re-run and both artefacts committed; `make gate`
   green in `backend/` and `frontend/`.

## 5. Test plan

| What | Where |
|---|---|
| Every registered view renders with no equity vocabulary, by field path | `tests/unit/presentation/test_asset_vocabulary.py` |
| The scanner rejects planted hits in all four live shapes | same file |
| The sweep's subject is the whole shipped catalog, and a plausible number of strings | same file |
| `detail` counts in the asset's own ticker, under a non-default locale too | `tests/unit/presentation/test_holdings_positions.py`, `test_attribution_headline.py` |
| `OrderImpact` declares no `units` field | `tests/unit/presentation/test_order_ticket_v2.py` |
| `DraftImpact` states no `units` | `tests/unit/domain/test_draft_impact.py` |
| The tool's `impact_block` emits no `unitsDisplay` | `tests/unit/agent/tools/test_draft_order.py` |
| `holding.label` is the asset's, in the payload and in the surface | `tests/unit/presentation/test_attribution_driver.py` |
| `delta_label` on both walks, and in the surface | `test_attribution_headline.py`, `test_attribution_window.py`, `test_attribution_waterfall.py` |
| Both artefacts match the registry | `test_catalog_doc.py`, `test_catalog_snapshot.py` (already gated) |
| The Dart bindings read the new paths, and the callout/strip draw `deltaLabel` | `frontend/app/test/components/…` |

## 6. Out of scope

- The `day_share` denominator (OD-5) — design's, and it needs its own ticket.
- Whether a Holdings row should show its ticker twice (OD-1's recorded cost).
- Any component layout beyond drawing one new string.
