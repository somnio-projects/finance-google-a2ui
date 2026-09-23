# 0024 — The header stays put

- **Area:** frontend (Home, Holdings, Activity, the Assistant, the catalog's
  index and detail pages, and the three first-run skeletons)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [frontend/0021](0021-three-defects-a-reader-found.md) OD-3 (the tab
  bar, the other anchor), [frontend/0009](0009-holdings-and-activity-tabs.md)
  (the tab app bar), [frontend/0016](0016-component-catalog-gallery.md) (the
  catalog board), [frontend/0020](0020-transition-states.md) (the skeletons
  and their goldens),
  [ADR-L](../../docs/adr/ADR-L-client-architecture.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The TL, scrolling the running app: *"en el scroll el header no se queda fijo y
deberia de todas las paginas"*, and then the reason it matters: *"el header
siempre tiene que estar visible este tambien acordate que es una app mobile al
final esto va a ir a mobile"*.

They showed two. On **Home** the greeting header — avatar, `Good evening /
Lbertuzzi`, the `Simulated portfolio` pill — slides off the top with the
content. On **Holdings** the `Holdings` title and its search and filter icons
do the same, so the two controls a reader reaches for while scrolling a long
list are the first things the list hides.

The bottom of the frame was fixed for this exact reason the same day: spec
0021 OD-3 put the catalog back inside the shell so the **tab bar** would stay
on screen, because the bar *"es la affordance que un lector ya conoce"*. The
header is the other anchor and nothing had been said about it.

No gate could have caught this. Not one test in `frontend/app/test` scrolled
anything — `grep -rl "drag\|fling\|scrollUntilVisible\|ensureVisible" test`
returned **nothing** — so every surface in this app was asserted only at
scroll offset 0, which is the one offset at which a scrolling header and a
pinned one are indistinguishable. The four page-shaped goldens are shot at
offset 0 too, for the same reason.

## 2. Scope

**In:** every top-level surface that has a header — Home, Holdings, Activity,
the Assistant, the catalog index and a catalog detail page — plus the three
first-run skeletons that stand in for the first three, plus the top safe-area
inset those now-permanent headers sit under.

**Out:** the sign-in screen (no header), the two order-ticket routes (a
Material `AppBar`, pinned by construction), the bottom sheets, and any change
to what a header *contains*.

## 3. Rulings

- **OD-1 — the cause is one shape repeated five times, and it is the header's
  position in the tree, not a missing scroll behaviour.** Home, Holdings,
  Activity and `CatalogBoard` (which both catalog pages and both catalog
  skeletons are built on) are each `ColoredBox → ListView(children: [header,
  …rest])`. The header is the scrollable's first child, so it scrolls:
  nothing is configured wrongly, it is simply inside the thing that moves.
  The Assistant is the same app built the other way — `Column(children:
  [AssistantHeader(), Expanded(ConversationTranscript()), …])` — and its
  header has never moved. **The fix is to make the other five look like the
  one that was already right**, not to reach for a sliver.

  MEASURED at 375 × 812, dragging the content up by 40 px — of which
  `dragFrom` spends the 20 px touch slop, so 20 px reaches the scrollable:

  | surface | header before | header after |
  |---|---|---|
  | Home | `Rect.fromLTRB(0.0, 0.0, 375.0, 150.0)` | `(0.0, −20.0, 375.0, 130.0)` |
  | Holdings | `(0.0, 0.0, 375.0, 58.0)` | `(0.0, −20.0, 375.0, 38.0)` |
  | Activity | `(0.0, 0.0, 375.0, 58.0)` | `(0.0, −40.0, 375.0, 18.0)` |
  | the Assistant | `(0.0, 0.0, 375.0, 66.0)` | `(0.0, 0.0, 375.0, 66.0)` |
  | catalog index | `(0.0, 0.0, 375.0, 89.0)` | `(0.0, −40.0, 375.0, 49.0)` |
  | catalog detail | `(0.0, 0.0, 375.0, 89.0)` | `(0.0, −40.0, 375.0, 49.0)` |

  After the fix, every `after` equals its `before`. With the suite's own
  300 px drag the old behaviour is starker still: the header is not merely
  moved, it is **gone from the widget tree** — `getRect` reports *"Found 0
  widgets with type HomeHeader"*, because a `ListView` disposes a child it
  has scrolled past. Heights are the test font's, which draws a block per
  glyph; they are consistent between the two columns, which is what the
  claim needs.

- **OD-2 — `Column` + `Expanded`, not `SliverAppBar` or
  `SliverPersistentHeader`.** A pinned sliver is the right tool when the
  header must *react* to the scroll — collapse, fade, stretch. None of these
  does; the design draws one height. A `SliverPersistentHeader` costs a
  delegate with `minExtent`/`maxExtent` **constants** per surface, and
  `TabAppBar` does not have one: it swaps its title row for a search field.
  A hard-coded extent that disagrees with the content is a clipped header —
  the defect this spec exists to remove, reintroduced as an off-by-one.
  `Expanded` asks the header for its own height and gives the rest to the
  scrollable, which is the mechanism that needs no number.

- **OD-3 — one home for the rule: `PinnedHeader`.** Six surfaces and three
  skeletons would otherwise each spell out "paint the band, hold it clear of
  the status bar", and the tenth (whoever adds the next screen) would copy
  whichever they found. `app/lib/features/shell/view/pinned_header.dart` is
  the band — colour, optional bottom rule, `SafeArea(bottom: false)` — and
  each surface keeps its own `Column` + `Expanded`, because *what* sits above
  the fold is the surface's answer and *how the band is drawn* is not.

  It lives under `features/shell/` beside `ShellTabBar`, the widget it is the
  counterpart of. It is not a component: `app/lib/components/` is the catalog
  seam and a header binds no payload.

- **OD-4 — the inset is the half that only matters once the header is
  pinned.** Nothing in this app applied a **top** safe-area inset: `SafeArea`
  appears four times and every one is a bottom edge (`ShellTabBar`,
  `AssistantComposer`, `HoldingsFilterSheet`, `SignInView`). That was
  survivable while the header scrolled — the status bar overlapped it only at
  offset 0 — and it is not once the header never moves. The `SafeArea` is
  **inside** the decoration, exactly as `ShellTabBar` does it at the other
  end, so the inset strip is painted in the band's own colour rather than
  showing the page through it. On today's web build the inset is zero and
  nothing moves; the test asserts it at a 44 px inset.

- **OD-5 — on Activity the band is the title *and* the chips.** The filter
  chips sit in their own `ColoredBox(tokens.header)` directly under the title
  row, and `ActivityFirstRun` already draws the two inside **one**
  `ColoredBox`: they are one band, and pinning half of it would split a
  continuous colour across the scroll boundary. Both go above the scrollable.
  The chips keep their own horizontal scroll — five chips are wider than a
  390-point phone (0020) — which a pinned band does not disturb.

- **OD-6 — a band is the width of the surface, and the golden said so.**
  The first version took the child's width, because a `Column`'s cross axis
  is `center` and not `stretch`. Every loaded header's child is a `Row`, so
  all six looked right; a **skeleton** header's child is a 150-point shimmer,
  and `HoldingsFirstRun` drew its header as a floating pill in the middle of
  the page — 4.36 % of the raster, caught by `holdings_first_run_light.png`,
  which is precisely what §6 of the testing rule keeps goldens for. The band
  is `width: double.infinity` now.

- **OD-7 — a rule that is drawn occupies space, and `DecoratedBox` does not
  know that.** The second version swapped the catalog bar's `Container` for a
  `DecoratedBox`. `Container` adds the border's own thickness to its padding;
  `DecoratedBox` paints the border and reserves nothing. The catalog bar lost
  1 px and **every row under it moved up by one** — 1.11 % of the raster
  against `develop`'s own render, over a bbox of `(0, 53, 1024, 815)`, which
  is "everything below the bar". `PinnedHeader` is a `Container`. Measured
  again afterwards: the new render is **pixel-identical** to `develop`'s for
  both catalog pages (`ImageChops.difference(...).getbbox()` → `None`).

- **OD-8 — the skeletons get the same shape, and no golden is
  regenerated.** `HomeFirstRun`, `HoldingsFirstRun` and `ActivityFirstRun`
  each put their shimmer header inside the same `ListView`. They are on
  screen for under a second, so nobody reported them — but a skeleton whose
  layout differs from the page it stands in for is a skeleton of the wrong
  shape, which is the argument 0020 already makes for the Activity chip row.
  They are restructured identically, and all six goldens over them pass
  untouched.

  **A finding, not fixed here.** With the tolerant comparator set to 0 % on
  an unmodified `develop`, `catalog_index_loading.png` and
  `catalog_detail_loading.png` are already **0.80 % stale** — they were shot
  before 0021 added the back control and rewrote the crumb as `Flexible`, and
  the 1.5 % tolerance has been absorbing the difference ever since. The other
  four goldens are exact. Nothing here changes those two pages' raster (OD-7),
  so regenerating them would be an unrelated edit hidden in this diff; it is
  reported instead, for 0021's author to take.

- **OD-9 — what is deliberately left alone, and why each is not the defect.**

  | Surface | Shape today | Ruling |
  |---|---|---|
  | The Assistant | `Column` + `Expanded`; header already outside the scrollable | **Correct already.** It gains the inset from OD-4 and nothing else; the measurement above is its regression guard. Its chips and composer are pinned at the bottom for the same reason and stay that way. |
  | Sign-in | `Scaffold(body: SafeArea(…))`, one centred column | No header to pin. |
  | `/order-ticket`, `/order-ticket-v2` | `Scaffold(appBar: AppBar(…))` | Material's own app bar: pinned and inset-correct by construction. Re-implementing it would be a regression. |
  | `HoldingsFilterSheet`, `SessionSheet` | modal bottom sheets | Not pages; no header, and their own scroll. |
  | `CatalogBoard`'s width cap | `Center` + `ConstrainedBox(1024)` | Untouched. The band is pinned **inside** the cap, so the bar stays the width of the board it belongs to rather than bleeding across a desktop window. |

- **OD-10 — no file was split.** Every touched file is inside the 150-line
  budget after the change; the largest, `catalog_loading.dart`, is unchanged
  in length because `header:` replaces a list entry line for line. The suite
  is two files (`header_scroll_harness.dart`, `header_scroll_blocs.dart`)
  because one would not have been, and the split is by how a surface is
  driven — a stubbed repository or a stubbed bloc — not "part 1 / part 2".

## 4. Acceptance criteria

1. **AC-1** — On Home, dragging the content up leaves the header's rect
   unchanged, and the content really moved.
2. **AC-2** — The same holds on Holdings, on Activity, on the catalog index
   and on a catalog detail page.
3. **AC-3** — The Assistant's header is unchanged by a drag on its transcript.
4. **AC-4** — No header is a descendant of the viewport it sits over.
5. **AC-5** — Holdings' search and filter controls still work after the list
   has scrolled: tapping search opens the field.
6. **AC-6** — A pinned header sits below a non-zero top safe-area inset, the
   inset strip is painted in the band's colour, and the band carries the rule
   the design draws under it.
7. **AC-7** — A surface whose content is shorter than the viewport has
   nothing to scroll and does not jump; no surface overflows at 375 × 812.
8. **AC-8** — The three first-run skeletons pin their header too, and the six
   page-shaped goldens are unchanged.
9. **AC-9** — `cd frontend && make gate` green, 100 % line coverage per file.

## 5. Test plan

| AC | How |
|---|---|
| 1, 2, 3 | `app/test/features/shell/header_stays_put_test.dart::stays put while … scrolls` — for each of the six surfaces: record `tester.getRect()` of the header, `dragFrom` the content, and assert both that the scroll position advanced **and** that the rect is identical. The scroll assertion is half the claim: if nothing moved, a pinned header and a scrolling one are the same picture. |
| 4 | the same suite, `::is never a descendant of the scrollable it sits over` — the mechanism, so a regression names itself |
| 5 | the same suite, `::keeps its controls usable after Holdings has scrolled` |
| 6, 7 | `app/test/features/shell/pinned_header_test.dart` — a `MediaQuery` with `padding: EdgeInsets.only(top: 44)`; the child's top edge, the band's height and painted colour, the border; and a short surface at 375 × 400 whose `maxScrollExtent` is 0 |
| 8 | `first_run_header_test.dart` — each skeleton pumped alone (they need no bloc) and its `PinnedHeader` asserted **outside** the `Viewport`. Written after review: `headerSurfaces()` lists only the six *loaded* surfaces and the goldens are shot at offset 0, so nothing here could have gone red. **Measured:** `HomeFirstRun`'s `Column` changed to a `ListView` turns it red; restored, green |
| all | `cd frontend && make gate` |

**Reproduced first.** The suite was written against `develop` at `5cb9a40`
and run before a line of `lib/` changed: **7 of 8 failed**, the one pass
being the Assistant, which was already right. Five failed by not finding the
header at all after the drag (`Found 0 widgets with type "HomeHeader"`) and
the structural test by finding it inside a `Viewport`. §3 OD-1 records the
rects from a shorter drag, where the header is still in the tree.

Two further mutations were not written by hand — the goldens caught them
while the fix was being built, and both are recorded above with their
measured cost (OD-6: 4.36 %; OD-7: 1.11 %, bbox `(0, 53, 1024, 815)`).

## 6. Out of scope

- Any change to what a header contains, including the `Gemini · A2UI` pill
  that 0021 §5 already declines to touch.
- A collapsing or shrinking header. The design draws one height; a scroll
  reaction is a design decision nobody has made.
- Regenerating the two stale catalog goldens (OD-8).
