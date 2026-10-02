# 0027 — The tax-lot table matches the UI Kit

- **Area:** frontend (`app/lib/components/taxlots_table/`)
- **Status:** In progress
- **Ticket:** GGU-116
- **Supersedes in part:** [frontend/0003](0003-taxlot-table.md) — OD-1, OD-2 and OD-3 are answered by fields the contract now serves; OD-4, OD-5 and OD-7 stand and are re-stated here
- **Also:** [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3 · D-14 · D-15, [ADR-K](../../docs/adr/ADR-K-response-shaping.md), `.claude/rules/frontend/contract-binding.md` (N-1…N-15)
- **Design:** [`assets/0027-taxlot-uikit/`](assets/0027-taxlot-uikit/) — the UI Kit A2UI *Tax-lot* frame, exported 2026-09-24
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

The tax-lot card on `develop` was built (GGU-57, spec `frontend/0003`) against
an earlier artboard. The UI Kit has moved, and the card no longer looks like
the component it implements:

| On `develop` | In the UI Kit |
|---|---|
| every row is a bordered, filled box with its own hairline | rows are flat on the card; a 4 px term rail is the only chrome, and one hairline divides the table from its footer |
| five columns: Acquired · Cost basis · Proceeds · Gain/loss · Term | **six**: Acquired · Shares · Cost basis · Market value · Unrealized · Holding period |
| the footer is a filled, bordered bar | the footer is a rule and a line of text: caption left, a large figure and two pills right |
| the tick box is decoration and can never be ticked | a ticked row is a real state, with a blue box and a tinted row |
| one desktop layout at every width | a desktop table **and** a phone layout of stacked lot cards |
| no loading state of its own | a skeleton with the card's own shape |
| the purple/indigo palette of the first artboard | a white (light) / `#17181C` (dark) card, teal long-term, amber short-term, `#026E4F` / `#4ADE9E` gains |

And the harder half: **the frame asks for figures the frozen contract does not
serve.** `taxlots.table.v1` is a frozen, digest-stamped entry in
`docs/catalog/view-catalog.snapshot.json`; this client may bind it and may not
invent it (N-1, N-2, N-3). §3's table is what the design asks for against what
the payload carries, and every ruling below follows from it.

## 2. What the design shows

Read off `assets/0027-taxlot-uikit/taxlot-uikit.svg` (geometry and colour are
exact there; the text is outlined, so type sizes were measured off the 2x
raster's ink extents).

- **Desktop** (card 640 × 346, content 600): a header row — title left, two
  legend pills right — column captions, four rows of 41 px on an 8 px rhythm,
  a 1 px rule, then the footer line.
- **A row**: a 4 × 41 term rail flush left (`#2FA584` long, `#B8790A` short in
  **both** themes), a 16 px tick box, then the six columns.
- **Selected**: the ticked rows take `#EBF1FF` (light) / `#17283C` (dark), the
  box fills `#3C90F1` / `#308CF5` with a white tick, and the footer caption
  changes from *Realized gain if sold* to *Realized on selected sale*.
- **Loading**: bars only — a title bar, two pill bars, a caption bar, four row
  bars, the rule, a footer bar. No text.
- **Mobile** (content 328): one stacked card per lot — an 80 px block with the
  rail, the tick box, the date and a term pill on the first line, then a
  four-cell grid *Shares · Cost basis · Mkt value · Unrealized*, caption over
  figure. The header and footer are the desktop ones.
- Light and dark for every state; the geometry is identical between them.

## 3. Design against contract — the gap table

`docs/catalog/view-catalog.snapshot.json`, component `TaxLotTable`, view
`taxlots.table.v1`, digest `c960b55bd552`, **`actions: []`**.

Its `options_schema` declares seven knobs — `currency`, `fields`, `locale`,
`lot_method`, `precision`, `quantity`, `symbol` — and two of them are load
bearing below: `locale` is why four captions come from the payload rather
than from Dart, and `lot_method` is why the rows are never re-sorted (N-10).
**None of them is a selection**, which is what OD-3 turns on. `symbol` and
`quantity` are *inputs* the caller already knows — they do not answer the
header gap, though the payload's `subtitle` ("Sell 75 NVDA under FIFO")
carries all three of symbol, quantity and method in one server-written
string.

| Design element | Contract field | Present? | What this build does, and what a viewer sees |
|---|---|---|---|
| `Acquired` — *Mar 12, 2021* | `lots[].acquired_on_display` | **yes** (new since 0003 OD-1) | bound verbatim — `01/13/2025` in the published example, not the design's `Mar 12, 2021`. The backend owns the format; re-spelling it here is N-1 |
| `Shares` — *30* | `lots[].units_display` | **yes** (new since 0003 OD-2) | bound verbatim. The raw `units` (`60.0000`) never reaches a `Text` (N-4) |
| `Cost basis` | `lots[].cost_basis.display`, caption `cost_basis.label` | **yes** | bound; the caption is the server's, so it follows the `locale` option |
| `Market value` | — | **no** | the nearest real field is `lots[].proceeds.display`, which *is* what the lot is worth at the sale price (`cost_basis + gain_loss` is `proceeds` in the published example). It is drawn in that column under the server's own caption, `proceeds.label` → **“Proceeds”**. A viewer sees the design's column, correctly filled, named what the payload calls it |
| `Unrealized` | `lots[].gain_loss.display` + `lots[].trend` | **yes**, caption **no** | the figure and its colour are bound; the caption stays **“Gain / loss”** (0003 OD-7). These are lots a sale consumes, so the figure beside the caption is *realised*; printing *Unrealized* over it would be the client asserting something the payload does not say |
| `Holding period` — *5.5 yr* | — | **no** | there is no duration field. The column keeps the design's slot and its caption, and carries the term pill only. A viewer sees `Long-term` where the design shows `Long-term  5.5 yr` |
| Header — *NVDA · 4 lots* | `title`, `subtitle` | **no** (not that string) | the payload's `title` takes the design's header slot and `subtitle` is drawn under it. Neither may be dropped (N-9); neither is a symbol and a lot count. A viewer sees two lines where the design has one |
| Ticked rows | `lots[].fully_sold` (`boolean`, `binding: flag`, `state: variant`) | **yes**, as *state* | the box, the tick and the row tint are bound to `fully_sold` — the lots this sale fully consumes. See OD-3 |
| Tapping a row to select it | no option, `actions: []` | **no** | nothing is tappable. See OD-3 |
| Footer total in green | `realized.amount.display` only | figure **yes**, direction **no** | the figure is bound; it is drawn in the primary text colour, not the design's green, because nothing in the payload states its sign (0003 OD-4) |
| Footer pills — *$4,100 LT* | `by_term[].realized.display` + `by_term[].label` | **yes**, abbreviation **no** | `+$26,679.60 Long-term` — the server's own short name for a half. Coining `LT` in Dart is client-authored copy that ignores `locale` (0003 OD-5) |

**Four fields to raise with the backend**: a per-lot market value, a per-lot
holding-period display string, a header/symbol line (or a `lots` count), and a
direction on `realized`. A lot-selection option is a fifth, and a product
decision before it is a contract one. They are listed in the PR under
*Backend gaps*; no ticket is opened from here.

## 4. Rulings

- **OD-1 — the six columns are the design's, and one of them is named by the
  payload rather than by the artboard.** *Market value* is the one column the
  contract cannot name: it serves `proceeds`, which is the same quantity under
  a different word, and `proceeds.label` is a server string that follows
  `locale`. Writing `Market value` as a Dart constant over a `proceeds` figure
  would be this client narrating the payload — the failure mode N-1 and N-9
  exist to prevent — and it would ignore the option that translates it. The
  three captions the contract supplies no label for (`Acquired`, `Shares`,
  `Holding period`) stay client-authored, which is the existing arrangement
  and is recorded in the gap table rather than discovered later.

- **OD-2 — SUPERSEDED by [`backend/0049`](../backend/0049-the-taxlot-table-gains-its-missing-fields.md) OD-2.** The field exists;
  the cell draws the pill and the duration side by side, as the artboard does.
  The ruling is kept below because the reasoning for *keeping the slot* rather
  than re-flowing five columns is what made the field cheap to land, and
  because the artboard corrected the rule that replaced it: the first draft of
  `holding_period_display` printed days (`363 d`) and the frame prints months
  (`8 mo`).

  ~~**the holding-period column keeps its slot and loses its text.**~~
  The alternative — dropping the column and re-flowing the other five — would
  make the table *look* like a different design and would have to be undone
  the day the field lands. The pill already lives in that column in the
  artboard, so keeping the slot costs nothing visually and the missing
  duration is one absent string rather than a reflowed layout. A duration is
  a derived figure (`now - acquired_on`), so it could not be computed here
  even with a clock: `DateTime.now(` is one of the twelve mechanisms
  `binding_rules_test.dart` fails on, and N-13 bans the device clock outright.

- **OD-3 — the ticked state is bound to `fully_sold`; nothing is tappable, and
  there is no local selection state either.** The contract publishes
  `lots[].fully_sold` as a **flag** with `state: variant` — the catalog's own
  word for "this field changes how the row looks" — and `ViewPayload.flag`
  exists to read exactly that. The design's *selected* variant is therefore
  not a client interaction at all: it is what the payload looks like when the
  proposed sale consumes some lots whole. That is the honest reading and it
  makes both artboards reachable from real payloads.

  **Local highlight state was considered and rejected.** A tick the viewer can
  toggle implies the figures below it move — the artboard's own selected state
  changes the footer from `$6,820` to `$35,833` — and that total is a sum over
  the ticked rows. Computing it is N-2; *not* computing it leaves a card whose
  footer contradicts its own ticks, which is worse than a card that cannot be
  ticked. So: no `onTap`, no `StatefulWidget`, no selection. When a selection
  option and a re-rendered total arrive, the round trip is a projection
  option, not client state (N-7, N-10).

- **OD-4 — the header is two lines because the payload is two strings.** The
  artboard's `NVDA · 4 lots` is a symbol and a count, and the contract serves
  neither. `title` and `subtitle` are both required, server-written strings and
  N-9 forbids dropping either. The title takes the design's 17 px slot; the
  subtitle sits under it in the muted role. The legend pills stay pinned right,
  so the header row still reads as the design's.

- **OD-5 — the palette is re-measured from this frame, and the term rails do
  not flip with the theme.** Every colour in `taxlot_tokens.dart` was read out
  of the SVG's own fills (the export is exact; the earlier values came from a
  rendered HTML page and half of them no longer exist in the design). The two
  rails are `#2FA584` and `#B8790A` in **both** artboards — the one pair the
  designer holds across themes, the way `mutedText` was held in the old file —
  and `taxlot_tokens_test.dart` asserts that rather than leaving it to look
  like an oversight.

- **OD-6 — the chart-palette agreement test is kept, and it now has a second
  half it does not cover.** `TaxLotTokens.light.gain` moves to `#026E4F`, the
  UI Kit's green, which is **not** `ChartTokens.light.barGain` (`#12805C`);
  dark agrees already (`#4ADE9E` both). The shared-role assertion is therefore
  narrowed to the roles the two pages still share (`surface`, `border`) and the
  divergence is asserted explicitly, with its reason, rather than deleted —
  the shape `ChartTokens.allocationLight` already uses for the Holdings screen
  (`frontend/0007` OD-2). **The Activity screen's term badges are a third
  declaration** (`ActivityTokens.shortBadge` / `longBadge`) and they disagree
  with this frame in light mode; they come from the Activity page, which this
  ticket does not touch, and `taxlot_tokens_test.dart` names the disagreement
  so the next person finds it stated instead of surprising. Design owns the
  merge; the client does not get to pick a winner by editing another screen's
  tokens.

- **OD-7 — the phone layout is a width breakpoint inside the card, not a
  media query.** The card does not know which screen it is on — it is laid
  out by whatever column the Assistant, the catalog or the Home shell puts it
  in — so `LayoutBuilder` and a single constant (`TaxLotMetrics.stackBelow =
  420`) choose the stacked form, the way `HoldingsAllocationCard` already
  does. Both forms bind the *same* model; there is no second read of the
  payload and no field only one of them shows.

- **OD-8 — the loading state is the component's own skeleton, composed from
  the 0015 primitives.** `ViewComponent.skeleton` exists for this and the
  design draws a shape that is recognisably this card, so the generic
  `SurfaceSkeleton` is not it. No `AnimationController` is declared here:
  reduced motion is inherited through `SkeletonShimmer` (ADR-L, rule §3b).

- **OD-10 — a golden frames chrome, never text, and this one was learned the
  expensive way.** The first attempt shot the whole card at both widths and
  both themes. It passed on macOS and **five of six failed on the Linux
  runner**, at 4.06–5.98 % against a 1.5 % tolerance — and light and dark
  differed by the *identical* pixel count (8132 both times), which is the
  signature that says the difference is not in the drawing: macOS and Linux
  lay glyphs out differently, and this card is a table of dates, counts and
  money columns. ADR-L D-15 measured that noise floor and `frontend/0004`
  already concluded it for a card of the same kind. Widening the tolerance
  would be threshold-fitting; the tolerance goes down as the noise is
  understood, never up to absorb a failure.

  So each golden now frames a region with **no text in it**, and the crops are
  computed from the same constants the layout uses (`TaxLotColumns.leadingWidth
  + railGap`), so a grid change moves the frame instead of letting a caption
  drift into shot:

  | Golden | Proves | No longer proves |
  |---|---|---|
  | `taxlot_rails{,_dark}` | both rail colours and the 4 px width, the 41/8 row rhythm, the tint of a consumed lot, the filled box with its painted tick, the hairline box of an untouched one | anything to the right of the tick box |
  | `taxlot_rails_phone` | the phone block's 80/4 rhythm, its rail colour, and the consumed lot's tint down the block's whole height | the tick box, the four-cell grid and the date |
  | `taxlot_surface{,_dark}` | the card plane: surface, 16 px radius, the shadow that replaces the old hairline | the padding, which an empty plane does not show |
  | `taxlot_skeleton{,_dark}` | the whole loading card — kept whole **because the artboard draws it with no text at all**, which is also why the waterfall's loading goldens are portable | nothing it draws is text |

  What the deleted goldens covered is asserted on the widget tree instead,
  where it already was and where a failure names the defect: the six captions
  and their order, every display string, the absent raw figures, the footer's
  caption and total, the two forms at their two widths.

  **And cropping horizontally was not enough, which is the sharper half of
  the lesson.** With the whole-card frames gone, `taxlot_rails_phone` still
  failed on the runner at **4.54 %**, and this time the count was not a
  glyph-layout signature — it was glyphs, in a frame built to exclude them.
  A horizontal crop applies to the **whole height**, and a phone block is two
  lines: the tick box sits on the first, but under it the four-cell grid
  begins at the rail's own gap, because `tilePadding` insets *vertically
  only*. Framing to the box therefore left 16 px of the *Shares* caption and
  its figure in shot. The frame now stops at `railWidth + railGap` — the rail
  and the band beside it, both flat fills — and the box's tick is asserted on
  the canvas in `taxlot_check_box_test.dart` instead, where emptying `paint`
  was watched turning it red.

  Stated as a rule: **a crop is only text-free if it is text-free at every
  height it covers.** Deriving the crop from a layout constant proves the
  frame moves with the grid; it does not prove the frame contains what you
  think, because the constant you reach for describes one line of a
  multi-line block. Check the narrowest text on *every* line the frame
  crosses, or crop vertically too.

  **Mutation-checked, both ways.** `railWidth` 4 → 5 turns all three rail
  goldens red; a **one-step** colour change on `selectedRow`
  (`#EBF1FF` → `#EBF1FE`) moves **32.5 %** of the table frame and
  **32.5 %** of the phone one — 640 px of 1968, which is every pixel of the
  tint. The same one-step error on a whole-card golden moves well under 1 %
  — under the tolerance, invisible. Cropping did not weaken these goldens;
  it is what makes them sensitive.

- **OD-9 — the files split again, by responsibility.** The directory was
  already 17 files; the new work adds the phone tile, the header, the tick
  box, the skeleton and a second metrics table, and splits the model in two.
  Nothing here is one file over 150 lines, and `make gate` is what says so.

## 5. Acceptance criteria

1. **AC-1** — at desktop width the card draws the design's six columns in
   order, on one grid shared by the captions and the rows, with the term rail
   flush left and a rule above the footer.
2. **AC-2** — every figure on screen is a `*.display` string the payload
   carries, and no raw member (`units`, any `*.amount`) reaches a `Text`.
3. **AC-3** — a lot with `fully_sold: true` draws a filled, ticked box and a
   tinted row; a lot with `fully_sold: false` draws an empty box and no tint;
   neither is tappable.
4. **AC-4** — below 420 px the card stacks each lot as the phone card, showing
   the same six values, and does not overflow.
5. **AC-5** — the term colours are asserted as literals in both themes, the
   rails are equal across themes, and the agreement with `ChartTokens` — and
   the two known divergences (`gain` in light, the Activity badges) — are
   asserted rather than left to a reader.
6. **AC-6** — the loading state renders this card's own skeleton, with no
   text and no `AnimationController` of its own.
7. **AC-7** — the edge cases render without overflow at both widths: one lot,
   many lots, all short-term, all long-term, gain and loss rows together, and
   a long title.
8. **AC-8** — every golden frames a region a raster can carry across
   platforms, and each one says what it proves and what it no longer proves.
9. **AC-9** — `cd frontend && make gate` green, 100 % line coverage per file,
   no file over 150 lines.

## 6. Test plan

| AC | How |
|---|---|
| 1 | `taxlots_table_card_test.dart` — the six captions, read from the generated snapshot's own example; `taxlot_parts_test.dart` for the shared grid and its six-cell assert |
| 2 | `taxlots_table_card_test.dart::never puts a raw figure on screen` and `taxlots_table_responsive_test.dart::neither form puts a raw figure on screen` — quantified over **every** path the snapshot marks `binding: raw` (`taxlot_raw_figures.dart`), not over a typed list |
| 3 | `taxlot_check_box_test.dart` — the box's decoration, the row's fill and the **painted tick** for both values of `fully_sold`; `taxlots_table_card_test.dart::nothing on the card is tappable` for the affordance half |
| 4 | `taxlots_table_responsive_test.dart` — pumped at 360 and at 640, asserting the phone tile appears and the desktop grid does not, and that neither overflows |
| 5 | `taxlot_tokens_test.dart` — literals, the cross-theme rail equality, the `ChartTokens` agreement and both divergences |
| 6 | `taxlots_table_skeleton_test.dart` — one bar per line the table will have, no `Text` at all, the card's own surface rather than the generic one, and the component seam (`ViewComponent.skeleton`). The "no `AnimationController` of its own" half is **structural, not asserted here**: `transition_rules_test.dart` is what fails a new skeleton that declares one, and `SkeletonShimmer` owns the only controllers in this tree |
| 7 | `taxlots_table_edges_test.dart` — one lot, eight lots, all-ST, all-LT, mixed trend, a 120-character title, each at both widths |
| 8 | `taxlots_table_golden_test.dart` — seven text-free frames through the tolerant comparator (ADR-L D-15). See OD-10 for what each one proves; mutation-checked twice, and the crops are derived from the layout's own constants so a caption cannot drift into shot |
| 9 | `make gate` |

## 7. Open decisions

| # | Question | Owner | Default if nobody answers |
|---|---|---|---|
| ~~OQ-1~~ | Does `taxlots.table.v1` gain a per-lot market value, or is `proceeds` the field the design means? | backend + design | **closed** by [`backend/0049`](../backend/0049-the-taxlot-table-gains-its-missing-fields.md) OD-1: `proceeds` **is** `quantity × current price`, so it is the field the design means. No column added; OD-1 below is unchanged and is now the answer rather than the fallback |
| ~~OQ-2~~ | Does a lot gain a holding-period display string (`5.5 yr`)? | backend | **closed** by `backend/0049` OD-2: `lots[].holding_period_display`. **OD-2 below is superseded** — the column no longer keeps an empty slot |
| OQ-3 | Does the view gain a header line — a symbol, a lot count — or does `title` keep that slot? | **design** | **open.** The artboard reads `NVDA · 4 lots`, so the *content* is not in doubt; what is design's is whether the card says that instead of a sentence. Worth knowing before it is raised: satisfying it needs **no new field** — `title` is already a server string the client binds, so this is a wording decision, not a contract change (`backend/0049` OD-6) |
| ~~OQ-4~~ | Does `realized` gain a `trend`, so the footer total can take the design's green? | backend | **closed** by `backend/0049` OD-4: `realized` is a `SignedTotal` carrying `direction`, and the footer binds it |
| OQ-5 | Is lot selection a product feature? If so it needs an option and a re-rendered total, not client state | product, then backend | `fully_sold` is the only ticked state (OD-3) |
| OQ-6 | Which term palette wins between this frame, `ChartTokens` and `ActivityTokens`? | design | each page keeps its own; the divergences are asserted (OD-6) |

## 8. Out of scope

- **The four missing fields.** They are listed in the PR body under *Backend
  gaps* for a human to raise as tickets; nothing here anticipates their shape.
- **A selection round trip.** OD-3: it needs an option and a re-rendered
  total, which is a projection change.
- **`ActivityTokens` and `ChartTokens`.** OD-6 names the divergences; another
  screen's design source is not this ticket's to overwrite.
- **A bundled font.** The design sets Inter and Roboto Mono; this app bundles
  neither and uses `tabularFigures` on the system face instead
  (`frontend/0002` OD-4, `frontend/0003` OD-6). Unchanged here.
- **The crypto migration (GGU-114).** It regenerates the catalog snapshot and
  therefore every example in this suite. The goldens no longer bind the
  example — OD-10's frames are built from the harness's own lots — so they
  survive it, which is a second dividend of cropping. This branch is built
  against today's contract; whichever lands second re-shoots the goldens.
