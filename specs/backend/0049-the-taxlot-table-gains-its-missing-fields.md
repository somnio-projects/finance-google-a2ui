# 0049 — The tax-lot table gains its missing fields

- **Area:** backend (`app/core/`, `app/domain/`, `app/presentation/`) and
  `frontend/` (the two new fields are bound in the same PR)
- **Status:** In progress
- **Answers:** [`frontend/0027`](../frontend/0027-the-taxlot-table-matches-the-ui-kit.md)
  §7 OQ-1 … OQ-4, which the client deliberately degraded rather than computed.
- **Supersedes nothing.** Extends `backend/0015` (the projection) and
  `backend/0024` §7 (what left the payload and why).

## 1. The problem

`frontend/0027` drew the UI Kit's tax-lot frame against the contract and found
four things the frame shows and `taxlots.table.v1` does not send. Each one was
**degraded and recorded** rather than invented client-side — a duration is
`as_of - acquired_on`, and deriving it in Dart is prohibition N-13 and one of
the twelve mechanisms `binding_rules_test.dart` fails on.

So the column exists, empty, with a client comment pointing here. That is the
correct interim state and it is also the whole reason this spec is short: the
slots are already drawn.

**The four are not one kind of question, and the ticket's title flattens them.**
Two are backend arithmetic, one is answered by reading what the payload already
means, and one belongs to design. Answering all four the same way is how a
design decision gets invented by whoever happened to pick the ticket up.

| OQ | The frame shows | Owner (0027 §7) | This spec |
|---|---|---|---|
| OQ-1 | a per-lot **market value** | backend + design | **answered, no field** — OD-1 |
| OQ-2 | a holding period, `5.5 yr` | backend | **new field** — OD-2, OD-3 |
| OQ-3 | a header line: symbol + lot count | **design** | **not answered here** — OD-6 |
| OQ-4 | the footer total in the design's green | backend | **new field** — OD-4 |

## 2. Scope

- `LotConsumption.held_days` — the holding period, counted in the domain.
- `TaxLotRow.holding_period_display` — that period as the string the cell prints.
- `app/core/period_display.py` — the one place the duration is worded.
- `fragments.SignedTotal` — a `Total` that knows which way it points.
- `TaxLotsTablePayload.realized` becomes a `SignedTotal`.
- `app/core/trend.py` declares `Trend` and `trend_of` returns it (OD-5).
- `frontend/`: both fields bound, goldens re-shot, catalog snapshot refreshed.

Out of scope: a market-value field (OD-1), a header line (OD-6), lot selection
(0027 OQ-5, its own ticket), and any change to which lots a sale consumes.

## 3. Decisions

### OD-1 — OQ-1 needs no field, because `proceeds` already **is** the market value

This reads like a design question and is not one. The table's rows are lots a
proposed sale **consumes**, and the payload already says what the row's
`proceeds` is:

```python
# app/domain/sale_results.py
proceeds: Money = Field(ge=0, description="``quantity * price``, in USD.")
price:    Money = Field(gt=0, description="The price the sale is costed at.")
```

`price` is the current quote the simulation costs the sale at, so
`proceeds == quantity × current price` — which is the definition of the market
value of those units. A `market_value` field would be a **second name for one
number**, and a payload whose two figures can disagree is the defect
`.claude/rules/backend/testing.md` names: *"a payload is wrong when two of its
own numbers disagree."* They could not disagree here; they would simply both be
maintained, and one of them would rot.

`frontend/0027` OD-1 already binds `proceeds` in that column under its own
server-supplied label. Nothing changes. What changes is that the question is
**closed with a reason** instead of left open — `proceeds` is not a stand-in
for the field the design wants, it is the field the design wants.

The half of OQ-1 that is genuinely design's — *should the caption read "Market
value"?* — is not this spec's, and is already handled the only honest way:
`proceeds.label` is a server string that follows `locale`, and 0027 OD-1
refuses to write `Market value` as a Dart constant over it.

### OD-2 — the duration is split at the term boundary the domain already owns

The artboard draws two forms — months and years — and the threshold between
them is **not invented**: it is `LONG_TERM_DAYS = 365`, the boundary
`app/domain/terms.py` already declares and the boundary this entire column
exists to communicate. It also happens to be where the design switches.

| Held | Prints |
|---|---|
| ≤ 365 days (short-term) | `8 mo` |
| > 365 days (long-term) | `5.5 yr` |

The dividend is a property, not a convenience: **the duration and the pill
beside it cannot contradict each other**, because both read the same
comparison. `short` implies the months form and `long` implies the years form,
by construction rather than by care, and the test asserts that relationship
rather than two more strings.

Years are `days / 365.25` at one decimal — the average year, so a leap day does
not move a figure the reader would otherwise see move. The boundary is safe in
both directions: 365 days is short-term and prints `12 mo`; 366 days prints
`1.0 yr`.

**The units and the rounding were read off the artboard, and the first draft of
this ruling was wrong.** It printed days below the boundary — `363 d` — from a
plausible argument about the tax rule, written without opening
`specs/frontend/assets/0027-taxlot-uikit/`. The frame draws `8 mo` and `4 mo`
beside `5.5 yr` and `4.1 yr`. It also settles a question the argument never
reached: its *Jan 15, 2026* lot reads **`8 mo`** at an `as_of` of roughly
2026-09-09, which is 7.8 average months, so **truncation answers `7 mo` and only
rounding draws what the designer drew**. Four measured strings pin both the unit
and the rounding, and `test_period_display.py` asserts all four.

The lesson is the one `presentation.md` already states about names and
guidance, in a place it was not expected: *the design page is the declaration*.
A rule derived from the domain can be internally consistent, defensible in
prose, and still not be the thing on the screen — and the file that would have
said so was in the repository the whole time.

### OD-3 — the duration is a **display string only**, with no numeric twin

Every other pair in this payload ships both halves, because a chart plots the
figure (ADR-E, N-4). Nothing plots a holding period — it is text in a cell
beside a pill — so a `held_days` on the wire would be a field nothing binds,
which is precisely what spec 0024 §7 deleted `price` and `remaining[]` for.

`held_days` therefore stops at the **domain** boundary: `LotConsumption`
carries it so the arithmetic happens where `term` is already derived from the
same two dates, and the projection turns it into a string. If a chart ever
needs the number, adding it back is one field and one line.

### OD-4 — OQ-4 is a new fragment, not a new field on `Total`

`realized` is a `Total`, which is `label` + `amount` and nothing else. The
footer wants the design's green, which means the payload has to say **which way
the figure points** — the client may not read the sign off the string (N-1) and
may not compare the number (N-2).

Adding an optional `trend` to `Total` would put a field on every headline
figure in every projection, almost all of which have no direction and would
never bind it. So: `SignedTotal(Total)` with `direction: Trend`, in
`fragments.py`, beside the `Delta` that established the vocabulary — ADR-K
D-16's rule for a genuinely new primitive.

The field is spelled **`direction`**, matching `Delta.direction`, and not
`trend`, which is how `TaxLotRow` spells the same concept one level down. That
divergence is real and is left alone on purpose: renaming `TaxLotRow.trend`
would break a field the client binds today, for tidiness. It is recorded here
so the next reader finds a decision instead of an accident.

### OD-5 — `trend_of` gets an honest annotation, and the token stays in two places

`app/core/trend.py::trend_of` was declared `-> str` and returns exactly `"up"`,
`"down"` or `"flat"` from three `Final` constants. That matters here because
`SignedTotal.direction: Trend` is fed by that function — the **precision-aware**
one, which the footer needs for the reason its own docstring gives: a loss of
half a cent renders `$0.00`, and a red total beside a zero is a contradiction
the reader cannot resolve.

The `Trend` literal naming those three tokens lived in
`app/domain/day_change.py`, so the annotation was unavailable: `core` may not
import `domain`.

**The plan was one definition in `core`, with `day_change` re-exporting it, and
the gate refused it.** `tests/unit/domain/test_package_boundaries.py` allows
`app.domain` to import exactly `app.core.errors`, `app.core.logging` and
`app.core.protocols`, and nothing else — so the re-export made `app.domain`
depend on `app.core.trend` and the suite went red naming it.

That is the layering test working, not an obstacle. Widening a deliberately
narrow whitelist in a feature PR — to share a **type name**, into a module the
domain does not otherwise need, when `day_change` already has its own
`trend_of` — is the worse trade of the two. So the literal is declared in both
modules, and
`tests/unit/core/test_trend.py::test_the_two_trend_declarations_agree`
**compares them**, which is this repository's documented answer to a property
that spans two declarations (`.claude/rules/backend/testing.md`: *"A property
that spans two declarations gets a test comparing them. A comment saying they
agree is not a test — it is where the hole hides."*)

### OD-6 — OQ-3 is design's, and is left open

*"Does the view gain a header line — a symbol, a lot count — or does `title`
keep that slot?"* Owner: **design**, per 0027 §7. Nothing in the payload or the
domain answers it; the answer is what the designer wants the card to say.

`presentation.md` is explicit about this class of thing — *"a sentence invented
here would be indistinguishable from one a designer approved"* — and the
component-name history in the same file is what happens when a provisional
answer is treated as a decision. So `title` and `subtitle` keep the slot, the
row stays in 0027 §7 with **design** in its owner column, and the ticket says
so rather than reporting four of four.

### OD-7 — the client rejected a token the contract permits, and that is fixed here

Found while binding OD-4. `TaxLotTrend` had two members, `up` and `down`, and
the component raised `PayloadContractException` on anything else. But both
`lots[].trend` and the new `realized.direction` come from `trend_of`, which
answers **three** tokens: a lot sold at exactly its basis realises zero, and
zero is `"flat"`.

So the client crashed on a payload the contract was always entitled to send.
Nobody had met it because the seeded scenario never realises exactly zero —
the same reason the sub-cent case needed a synthetic simulation to test at all
(§5 row 4). A design state the artboard does not draw is not the same thing as
a state the schema does not permit, and the enum was written from the artboard.

`flat` is now a member, takes the primary text colour — the absence of a
direction, not a third hue — and both the row and the footer read it through
one function. Asserted in `taxlots_table_contract_test.dart` in both
directions: `"sideways"` still raises, `"flat"` no longer does.

It is fixed here rather than filed because the field that exposed it is this
spec's, and shipping `direction` into a reader that rejects a third of its
range would have been adding the defect rather than finding it.

### OD-8 — no golden covers either field, and that is said rather than implied

`taxlot_golden_frame.dart` crops every tax-lot golden to the row's **left
chrome** and is deliberately text-free, because glyph edges carry nearly all
cross-platform raster noise (ADR-L D-15, `frontend/0027` OD-10). A duration and
a coloured total are both text, so **no golden in this suite can see either
change** — and all fourteen passed untouched, which is the crop working and not
evidence about this PR.

The screen evidence is therefore widget tests that read the tree:
`taxlot_row_tile_test.dart::prints the holding period the backend worded` and
`taxlot_footer_colour_test.dart`, three cases. The first names the gap in its
own comment, so the next person does not read fourteen green goldens as
coverage of a string none of them contains.

## 3b. API contract

No path, verb or status code changes. `taxlots.table.v1` is served by the
existing `PORTFOLIO_ENDPOINTS` and selected by `?view=`; both additions are
**additive** fields on an existing DTO, so `/v1` is not broken and no `v2` id
is minted (`api-design.md` § *Versioning*).

```diff
  lots[]:
+   holding_period_display: str   # max_length 16, e.g. "5.5 yr" / "142 d"
- realized: Total                 # label + amount
+ realized: SignedTotal           # label + amount + direction: "up"|"down"|"flat"
```

Error codes are unchanged: the render's three data errors (`SymbolNotFound`,
`SaleQuantity`, `PositionTooSmall`) are spec 0015's and neither addition can
raise. `holding_period_days` can raise `PortfolioInvariantError` on a lot dated
after `as_of`, and already does today — `term` is derived from the same call, so
this adds no new failure path.

## 3c. Data model & migration

**None.** Nothing is persisted. `held_days` is a field on the frozen in-memory
`LotConsumption`, derived at simulation time from two dates the lot already
carries; `holding_period_display` exists only on the wire. No table, no column,
no Alembic revision.

## 3d. Security notes

No new route, so the existing bearer-token dependency covers it unchanged. The
two additions carry no subject data: a duration and a direction token are
derived from a lot the caller already owns, and neither can widen what a
principal can read. Nothing here is logged — the render writes no log line —
and no figure reaches a problem response.

## 4. Acceptance criteria

1. **AC-1** — `taxlots.table.v1` serves `lots[].holding_period_display`, a
   bounded, described, exemplified string.
2. **AC-2** — It prints `<n> d` at 365 days held and `<n.n> yr` at 366, and
   **agrees with `term` on every row of every render**, asserted as the
   relationship rather than as two literals.
3. **AC-3** — `realized` is a `SignedTotal` carrying `direction`, and
   `direction` is decided from the **rounded** figure, so a half-cent loss is
   `flat` beside `$0.00`.
4. **AC-4** — No `market_value` field is added, and OD-1's reasoning is in the
   spec (OQ-1 closed).
5. **AC-5** — OQ-3 stays open with **design** as its owner; nothing in this PR
   invents a header line (OQ-3 not closed, on purpose).
6. **AC-6** — `app.core.trend.trend_of` is annotated `-> Trend`, and the two
   declarations of `Trend` are asserted equal. **Not** one definition: the
   layering test refuses it, and OD-5 records why widening that whitelist is
   the worse fix.
7. **AC-7** — Both catalog artefacts regenerated and committed; `/v1/views`
   and OpenAPI show the new field and the new fragment.
8. **AC-8** — The client binds both fields: the duration **beside** the term
   pill (the artboard's arrangement), and the footer total coloured from
   `realized.direction`, with `flat` accepted (OD-7) and asserted on screen by
   widget tests rather than by a golden (OD-8).
9. **AC-9** — `cd backend && make gate` and `cd frontend && make gate` green.

## 5. Test plan

| # | What | Where |
|---|---|---|
| 1 | `holding_period_display` at 0, 1, 364, 365, 366, 400, 2000 days | `tests/unit/core/test_period_display.py` |
| 2 | The **relationship**: every row's duration form matches its `term` | `tests/unit/presentation/test_taxlots_table.py` |
| 3 | `held_days` equals `holding_period_days(acquired_on, as_of=…)` for every consumed lot | `tests/unit/domain/test_sales.py` |
| 4 | `direction` from the rounded figure: a −$0.004 realised result is `flat` | `tests/unit/presentation/test_taxlots_table.py` |
| 5 | The two `Trend` declarations are equal (OD-5) | `tests/unit/core/test_trend.py` |
| 6 | The catalog contract and snapshot carry the new field | the existing `catalog-check` |
| 7 | The duration reaches the screen | `taxlot_row_tile_test.dart` (**not** a golden — OD-8) |
| 8 | The footer total's three colours | `taxlot_footer_colour_test.dart` |
| 9 | `"flat"` is accepted and `"sideways"` is not | `taxlots_table_contract_test.dart` |

## 6. Open decisions

| # | Question | Owner | Default if nobody answers |
|---|---|---|---|
| OQ-1 | Should the *Market value* caption be served as `proceeds.label`, i.e. does design want that word? | design | `proceeds.label` stays `"Proceeds"`; the client never writes the other word itself (0027 OD-1) |
| OQ-2 | Does a header line replace `title`/`subtitle`? (0027 OQ-3, still open) | design | two lines of `title`/`subtitle` |
| OQ-3 | Should the duration follow `locale` — `142 j`, `5,5 a` in French? | design + backend | English units. `locale` today only moves separators and date order; inventing a unit vocabulary per locale is a bigger decision than this spec |
