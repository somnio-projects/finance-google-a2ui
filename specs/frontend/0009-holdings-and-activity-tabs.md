# 0009 — The Holdings and Activity tabs

- **Area:** frontend (the client half of backend/0028)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0028](../backend/0028-holdings-and-activity.md) (`holdings.positions.v1`, `activity.timeline.v1`), [backend/0026](../backend/0026-the-home-shell.md) (the shell, `holdings.allocation.v1` grouped), [`frontend/0007`](0007-allocation-summary.md) (the donut), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-13/D-14, [ADR-I](../../docs/adr/ADR-I-client-routing.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

Two of the shell's four tabs were placeholders. `/holdings` opened the
component catalog index and `/activity` a static frame whose filter words and
note lived in the Dart file. `Holdings.dc.html` and `Activity.dc.html` are
full screens — a card, a segmented control and a data-dense list; a chip row
and a dated timeline — and the instruction is that the app be **identical** to
the design, light and dark.

Everything on both screens is a word or a figure (`90 sh · avg $826.67`,
`+$588 realized`, `THIS WEEK`), so the client binds two projections and
composes nothing. The only state that lives here is *which* declared option is
in force: `group_by`, `kind`, and which of the two lists the Holdings tab shows.

## 2. Measured, not transcribed

Read out of the rendered pages with `getComputedStyle`, light and dark. What
`HomeTokens` (0026 §2) already carries — page, card, text, muted, gain, loss,
the segmented pill, the ticker chip — is reused, not declared twice. The rest is
`HoldingsTokens` and `ActivityTokens`, one `ThemeExtension` each, both
registered in `AppTheme` beside the existing ones.

| Element | Light | Dark |
|---|---|---|
| tab app bar | title 22/500 `#1A1B20`; two quiet icons (search, filter) `#44464E` | title `#E5E1E9`; icons `#A4A6B0` |
| header card | r20, border `#EAE7F0`, pad 18; total 27/400 −0.5 tracking; gain 13/500 in the trend colour, period 11.5 muted; `Catalog` chip 11/500 bordered r12 | border `#24252D` |
| `By asset class \| By sector` | track `#EFEAF7`; selected pill white, text `#3A2F70` 13/500; other `#6F6A86` | track `#232036`; selected `#3A3556` / `#E0E0FF`; other `#9A9AB0` |
| `✓ By position \| By asset class` | the Home range selector's 38px bordered pill, `#4F5DFF` fill and white text when selected | `#B9C0FF` / `#151A54` |
| position tile | r14, border `#EAE7F0`; left accent 4px in the day's colour (`#12805C` up · `#C0362C` down · `#9AA0AA` flat); expanded: border `#D7D2E6`, head `#F4F2FC`, indigo shadow `#4F5DFF` @18 % | border `#24252D`; expanded `#3A3556` / `#1B1C28` |
| ticker badge | 40×40 r10 `#EAE7F5` / `#4A3F8A` 12/500; cash `#EEF0F2` / `#5F6169` 11/500 | inherits `HomeTokens.ticker` |
| `Day` · `Price` · `Weight` | tiles `#F7F6FB` r10 pad 10×8; label 10.5 muted; value 12.5/500 | `#101017` |
| `Ask the assistant about this` | gradient `#EEF0FF`→`#F3EDFF`, border `#D9DCFF`, r12; 20px dot `#4F5DFF`→`#7A5CFF`; words 13/500 `#3A2F70`; chevron `#7A5CFF` | `#232036`→`#26283A` |
| filter chips | r9 pad 13×7; 12.5; selected `#4F5DFF` / white with `✓`; others card fill, border `#C4C6D0` | selected `#B9C0FF` / `#151A54` |
| simulation note | 6px amber dot `#F0A52E` with an 18 % halo; 11 `#7C7E88` | same |
| section heading | 11.5/500, +0.4 tracking, `#5F6169`, uppercase as the backend writes it | `#A4A6B0` |
| entry tile | r16, border `#EAE7F0`, pad 15×13; icon tile 40×40 r12 per kind — buy `#EAE7F5`/`#4A3F8A` `↓`, sell `#F0EEF4`/`#5F6169` `↑`, dividend `#DBEEE7`/`#0C6A52` `$`, deposit `#E2ECF7`/`#2B5A86` `+`; title 14/500; caption 11.5 muted; amount 14/500 in the row's `tone`; badge 11 `#8A8D96` | buy `#232036`/`#C9CBFF` · sell `#1F2028`/`#A4A6B0` · dividend `#153029`/`#4ADE9E` · deposit `#182634`/`#83B3E0` |
| term badge | r6 pad 6×2, 10/500; `ST gain` `#FBE9C8`/`#8A5A00`; `LT gain` `#CFE9E3`/`#0C5A52` | `#3A2C12`/`#FFC971` · `#12332C`/`#4ADE9E` |

## 3. Rulings

- **OD-1 — two blocs, one option each.** `HoldingsBloc` holds `group_by`
  and which list shows; `ActivityBloc` holds `kind`. Both send the declared
  option to the repository and bind what comes back. The segmented `By
  position | By asset class` is the one piece of state with no option behind
  it (backend/0028 OD-7): it chooses between two payloads already loaded —
  `holdings.positions.v1` and the class rows of `holdings.allocation.v1` — so
  switching it costs no request.
- **OD-2 — the header card is the Home card, expanded.** Its figures come
  from `holdings.positions.v1` (`total`, `gain`) and its ring from
  `holdings.allocation.v1` with `headline=false`, rendered through the same
  `ComponentHost` a `?view=` read goes through. No second donut.
- **OD-3 — the hand-off is a route.** `Ask the assistant about this` navigates
  to `/ask?ask=<ask.text>`; `ConversationPage` reads the query and sends it as
  its first message. The Home question chips take the same route, so one
  mechanism serves both designs (ADR-I). The question is the backend's words,
  URL-encoded and decoded, never rephrased.
- **OD-4 — the first row starts expanded**, because the design draws NVDA
  pressed and a list where nothing is open hides the hand-off the screen
  exists to show. Tapping any row expands it and collapses the other; tapping
  the open one closes it. Cash rows have no details and do not expand.
- **OD-5 — `Catalog` is a chip, and it opens the catalog.** Every card the
  design marks as a catalog component wears the chip; tapping it goes to
  `/catalog`, where the component index that used to *be* the Holdings tab now
  lives. The chip is one widget (`CatalogChip`) used by Home and Holdings.
- **OD-6 — icons are glyphs, colours are tokens.** The client maps `kind` →
  `↓ ↑ $ +` and a tile colour, `tone`/`trend` → gain/loss/muted, `term` →
  amber/teal. It never derives any of them from an amount's sign or a date:
  the backend already decided and the client only looks up (ADR-K, N-13).
- **OD-7 — the app-bar icons are honest placeholders.** Search and filter are
  drawn because the design draws them; tapping says the feature is not part
  of this preview. They are not hidden, because the screen would not match,
  and not faked, because a dead control that looks live is worse than a
  labelled one.
- **OD-8 — a flag is read as a flag.** `is_cash` is a boolean in the
  contract and `ViewPayload.text` refuses anything but a string, so the
  package gains `flag(path)`: the client *branches* on it and never prints
  it, which is what keeps it clear of the numbers rule. Reading a boolean
  through `text(...) == 'true'` would have made the backend spell a bool as a
  word to suit the client — the dependency pointing the wrong way.
- **OD-9 — the caption and its badge are one line.** The design hugs
  `ST gain` to `40 sh @ $73.10 · Wed`; a `Row` of a text and a badge
  overflows the moment a viewport is narrower than both, and a red overflow
  is the gate's answer. The badge is a `WidgetSpan` inside the caption's
  `Text.rich`, so the line ellipsizes as one and the badge never leaves the
  words it qualifies. The position tile's left accent is a strip inside the
  rounded card for a similar reason: Flutter cannot paint a radius on a
  border whose sides differ.

## 4. Test decision

Bloc: each event produces the state the view binds, the option reaches the
repository verbatim, a failure carries the backend's problem. Widget: both
views over fixture payloads (`test/helpers/tab_fixtures.dart`) assert every
bound string, the expand/collapse rule, the hand-off's route, the chip and
segment selections, and the failure state; the term badge and the position
head are covered through their tiles. Theme: `tab_tokens_test.dart` pins the
measured colours above, light and dark, so a palette edit is a visible diff.
Router: `/holdings` builds `HoldingsPage`, `/catalog` the index, `/ask?ask=`
reaches the conversation with the question. The gate's 100 % line coverage
holds for every new file.

Not run here: a golden per screen — the tokens test covers the colours and
the widget tests the words; pixel comparison against the design is done by
eye in the PR's screenshots, light and dark.
