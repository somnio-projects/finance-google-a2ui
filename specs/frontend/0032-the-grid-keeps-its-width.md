# 0032 — The comparison grid keeps its width and scrolls

**Status:** In progress · **Ticket:** GGU-144 · **Area:** `frontend/`
Follows [`frontend/0031`](0031-the-comparison-is-measured.md), which measured
this card, and [`backend/0052`](../backend/0052-the-comparison-gets-a-turn.md),
which made it reachable — and therefore visible at a width nobody had checked.

## 1. Problem

The design draws this card at **571.367 pt** on a 1024 artboard, so its metric
grid gets a 533.367 pt content box. `AppShell` caps the app at **430 pt**, on a
phone *and* on a desktop, deliberately: *"a stretched card is not the same
design at a different size, it is a different design."*

**That ruling is written in exactly one place and it is not a spec.** It lives
in `app_shell.dart`'s own doc comment. [`backend/0026`](../backend/0026-the-home-shell.md)
is the Home shell's spec and says nothing about the width; no spec does. The
citation is given as-is rather than dressed up, because a decision that exists
only as a code comment is still the decision — and §7 records it as something
to fix rather than something to quietly cite around.

So the grid is asked to lay four tracks out in **392 pt** where the designer
gave it 533. It cannot, and it does not say so — it compresses every track by
about a quarter and the figures break mid-number. Measured in the running
client at `local+a31149c`: `$20,000.` over `00`, `+$8,397.3` over `9`.

**Nothing in the suite could see this.** Every test of this card pumps it at
`designCardWidth`, which is precisely the width at which the layout is
correct. A component checked only at the size its design was drawn at has been
checked at the one size that cannot fail.

## 2. Decision

**D-1 — the grid keeps the design's width and scrolls horizontally below it.**
`ScenarioGridViewport` gives the grid `max(available, minGridWidth)` inside a
horizontal scroll view. At or above the minimum nothing scrolls and the layout
is byte-identical to before, which is why the geometry suite and both goldens
are untouched.

**D-2 — the minimum is the card's content box on the artboard (533.367).**
This is a *decision* dressed as a measurement and worth naming as such: the
design draws no narrow artboard for this card, so some width had to be chosen,
and this is the only one the design can be said to endorse — at it, every
track is exactly what `getComputedStyle` reported.

## 3. The three alternatives, and why each was turned down

| Option | Why not |
|---|---|
| Widen the shell on a wide viewport | Contradicts `AppShell`'s ruling, which has reasoning behind it and is not an oversight. Overturning it is a design decision about the whole app, not a fix for one card. |
| Scale the table to fit (`FittedBox`) | Preserves every measured proportion exactly — and defeats dynamic type. The figures would stop responding to the system font size, which `.claude/rules/flutter/best-practices.md` requires. An accessibility regression is a worse trade than a scroll. |
| Ask the backend for fewer columns on a narrow client | The client deciding what to compare. That is a product decision and N-10's neighbourhood; if it is ever right it is a design call, not a layout one. |

## 4. What this costs, stated plainly

The metric names scroll away with everything else, so at the far right a
reader sees three columns of figures and no row labels. **Pinning that first
track is the better answer** and it is not free: two scroll views that stay in
step need linked controllers (a dependency) or fixed row heights (a measured
value the design does not give at this width), and each row's height is
currently set by the metric cell, which is two lines against the value cell's
one. Recorded as a known improvement rather than guessed at.

Mitigated by the card itself: the winner's tint and tick travel with their own
cell, so *which column won this row* is answered wherever you have scrolled to.

## 5. Acceptance criteria

- **AC-1** Below `minGridWidth` the grid is laid out at `minGridWidth` and
  scrolls horizontally.
- **AC-2** At `minGridWidth` and above it fills its surface and does not
  scroll.
- **AC-3** Every track is the width the design measured, at **430** as well as
  at the artboard.
- **AC-4** The geometry suite and both goldens are unchanged.
- **AC-5** `cd frontend && make gate` green.

## 6. Test plan

`scenario_comparison_viewport_test.dart`, pumping the card at **430** — the
width no other test uses, which is the point.

**The first draft asserted the symptom and had to be thrown away**, and that
is worth keeping. It checked *no figure is broken across two lines*, and it
failed **at the design's own width**: `flutter test` renders every glyph in
the test font as a full em square, so `+$7,062.50` "needs" 135 pt there
against a track the designer sized at 121. The assertion was measuring the
test font, not the layout. Geometry is what a widget test can prove about this
card; typography is what a golden cannot prove either (`.claude/rules/
frontend/testing.md` §6). The suite asserts the tracks.

**Mutation check.** Replacing the minimum with `constraints.maxWidth` — so
everything still compiles and the viewport is still in the tree — turns
exactly the three narrow-width tests red and leaves the geometry suite green:

```
FAILED …viewport_test.dart: gives every track the width the design measured
FAILED …viewport_test.dart: keeps the design width when the shell is narrower
FAILED …viewport_test.dart: scrolls sideways so the last column can be reached
62 passed, 3 failed          # restored: 65 passed
```

## 7. Open decisions

**OD-1 — the shell's width ruling is not in a spec.** `AppShell.maxWidth = 430`
and the sentence justifying it exist only as a doc comment on the widget, and
this spec had to cite a code comment as the authority it is bound by. Ten
files cite "spec 0026" for shell and Home matters and resolve to
`backend/0026`, which does not mention a width. Somebody should move the
ruling into that spec; doing it here would mean editing a backend spec from a
frontend ticket.

**OD-2 — the other catalog cards have not been checked at 430.** This ticket
fixed the card where the defect was found. The shell/artboard mismatch is
general: every component is designed at 1024 and shown at 430. The tax-lot
table and the order ticket restructure rather than tabulate, so they are
probably fine, but *probably* is the word — nobody has pumped them at 430
either. Raised rather than assumed.
