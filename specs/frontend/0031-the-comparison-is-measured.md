# 0031 — The comparison card is measured, not remembered

**Status:** In progress · **Ticket:** GGU-141 · **Area:** `frontend/`
**Supersedes nothing.** Amends the visual half of
[`frontend/0004`](0004-scenario-comparison-card.md) and binds the contract
[`backend/0051`](../backend/0051-the-comparison-ranks-what-it-can-defend.md)
added.

## 1. Problem

GGU-138 taught the card to *read* the verdict the backend had started
sending — a marked winner, a recommended column, a summary sentence. What it
could not do was draw them the way the design draws them, because the values
it drew them with were **invented**: a green that was not the design's green,
a tick that was not the design's tick, and a recommendation rendered in the
colour the design reserves for something else.

That is the same defect class `frontend/0004` opened with and
`.claude/rules/ci-conventions.md` §5 keeps finding: *a second declaration of a
fact, free to drift from the first.* A colour chosen from memory of a Figma
frame is a second declaration of a design decision.

## 2. Where the measurements come from

`.design-refs/Catalog_ScenarioComparison.dc.html` — a **rendered** DOM with
inline CSS, for both the `L1 · Light · 1024` and `D1 · Dark · 1024` artboards.
It is gitignored and local; the repository holds the values it yields, in
`scenario_comparison_tokens.dart`, `scenario_comparison_verdict_tokens.dart`
and `scenario_comparison_text.dart`, each pinned by a test.

> **Corrected 2026-09-28, and the correction matters more than the fact.**
> This section said that file was *"the designer's exported, rendered DOM"*,
> and every token file repeated it. It is not. Miriam said so plainly in
> `#finance-google-a2ui-dev`: *"yo no hice los html / eso es lo que hizo Claude
> / osea lo que me pasaron a mi para que mejore."* Those files are a catalog
> mock **this repository generated and handed to her as a starting point**, so
> calling a measurement of one "measured from the design" inverts the direction
> of the whole handoff.
>
> What survives is the *method* — measure, do not remember — and the values
> themselves stand until the artboard says otherwise. What does not survive is
> the authority: where this file and Miriam's Figma
> (`figma.com/design/rFA8ZEEOOvnOyq7IrTObma/A2UI-FINANCE-UI-KIT`) disagree,
> **Figma wins**, and a component is re-measured against it rather than against
> the mock. Spec `frontend/0033` is the first one done that way.

Read off that file:

| | light | dark |
|---|---|---|
| winner tint | `#E3F3EC` | `#12291F` |
| winner border | `#BFE4D1` | `#1F4536` |
| winner figure / tick fill | `#12805C` | `#4ADE9E` |
| normal figure | `#1A1B20` | `#E5E1E9` |
| direction hint | `#A0A3AC` | `#75777F` |
| recommended header fill | `#EEF0FF` | `#20223A` |
| recommended header border | `#CDD2FF` | `#3A3B6E` |
| recommended tag fill / border / text | `#E2E0FB` · `#C9C6F5` · `#3A2F70` | `#2A2748` · `#3F3A68` · `#C9C6FF` |

Geometry, same source: cell `padding:9px 10px`, `border-radius:8`, `gap:6`;
tick a `15×15` disc; figure `13.5px` mono, `600` when it wins and `400`
otherwise; hint `400 9.5px`; tag `600 9px` at `.04em`, `radius:20`,
`padding:2px 8px`.

## 3. Decisions

**D-1 — Green is a gain; lavender is the thing to look at.** The card's
largest visual error was drawing the recommended column in the winner's
green. The design spends green on `gain` — the colour of a figure that went
up — and marks the recommendation with the same `hlBg`/`hlBorder` lavender
the order ticket uses to highlight a leg. Conflating them made the card claim
*"this is good"* where the design claims *"look here"*.

**D-2 — The tag is not uppercased and the star is not in the string.** The
design's CSS uppercases the label with `text-transform` and writes `★` into
the text. `recommendation_label` is a server-written string, so the client
renders it verbatim and draws the star as an icon beside it (N-1, N-9).

**D-3 — The tick is `Icons.check` in a drawn disc, not a `✓` glyph.** A style
slot for the design's `font:700 9px ✓` was written and deleted: the glyph is
not in Roboto and rendered as a filled blob.

**D-4 — The arrow moved into the contract, not into the client.** The design
writes `higher is better ▲`. Prepending `▲` in Dart would be the client
editing a formatted value, and a Dart `if (label == 'higher is better')`
would be a second declaration of a fact `presentation/scenario_rows.py`
already owns. The arrow is now part of `HIGHER`/`LOWER` there, and the
catalog artefacts were regenerated in the same commit.

## 4. Open decisions

**OD-1 — `columns[].label` has no slot in the redesigned frame, and is now
announced rather than drawn.** The design's header is two lines, `FIFO` over
`default order`, which are `method` and `caption`. The long form
`FIFO — oldest lots first` is still served and still rendered — as the header
cell's semantics label — because dropping a server-written label outright is
N-9. **This is a decision to surface, not one to make quietly:** if it should
be visible, the frame is what has to change, and the alternative (a third
header line) is a deliberate divergence from the artboard.

**OD-2 — the frame draws no subject strip and no spread block; the card keeps
both.** `backend/0051` OD-3/OD-5 decided to keep them: the subject strip is
the card's premise (*which* sale is being compared) and the spread names the
two ends of the range. The design's artboard shows neither. Kept, and
recorded here so the divergence is visible rather than inferred.

**OD-3 — `▲`/`▼` are not in Roboto.** On the Flutter test renderer they are
tofu. Flutter web's CanvasKit fetches a fallback for missing glyphs, so the
deployed client is expected to draw them; **that is an expectation, not a
measurement**, and it is verified on dev after this ships rather than
asserted here. If it does not hold, the fix is a bundled symbol font, not a
client-side substitution.

## 5. Acceptance criteria

- **AC-1** Every colour and type value the card draws is read from the
  measured token files, and each is pinned by a test.
- **AC-2** The recommended column is lavender; the winner's cell is green;
  no widget draws one in the other's role.
- **AC-3** `columns[].label` reaches a screen reader on the column it
  belongs to (`scenario_comparison_table_test.dart`).
- **AC-4** `rows[].direction_label` is rendered verbatim, arrow included,
  and appears whether or not anyone won the row
  (`scenario_comparison_silence_test.dart`).
- **AC-5** `cd frontend && make gate` and `cd backend && make gate` green.

## 6. Test decision

No new suite. The measured values are pinned where the old invented ones
were — `scenario_comparison_tokens_test.dart` and
`scenario_comparison_layout_test.dart` — and three existing tests were
corrected rather than relaxed, each for a stated reason:

- `_rowBorder` selected the table's **first** `DecoratedBox`, and the
  redesign put two above the rows. It now selects by the property that makes
  something a row rule (a top border and no side border). *A finder that
  keeps matching after the thing it was aimed at moved is worse than one
  that breaks.*
- the silence suite asserted `higher is better ▲` never appears. That was
  true only while the string did not exist; it is a per-row label, not a
  verdict, so it moved from the "invents nothing" list to an assertion that
  it **is** drawn.
- the verdict suite looked for `Icons.check_circle`, which D-3 replaced.
