# 0020 — Transition states: every wait has a shape

- **Area:** frontend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [frontend/0015](0015-loading-states.md) (the skeleton vocabulary this extends — OD-3 and OD-5 are load-bearing here), [frontend/0009](0009-holdings-and-activity-tabs.md) (the two tabs and their options), [frontend/0016](0016-component-catalog-gallery.md) (the gallery), [frontend/0006](0006-order-ticket.md) / [0013](0013-order-ticket-v2.md) (the ticket's in-flight marker), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3 (the component seam), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) / [`specs/client/0003`](../client/0003-client-backend-contract.md) N-3, N-9, N-10
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Spec 0015 built a skeleton vocabulary — `SkeletonShimmer`, `SkeletonPulse`,
`SkeletonCaption`, `SurfaceSkeleton`, the per-component `skeleton()` override
and `ComponentSkeletonHost` — and spent it on **three** moments: the Home
tab's first paint, the Home hero's range change, and a surface being composed
in the Assistant transcript and the gallery's `Loading · skeleton` card.

Every other wait in the app was left as it was, and the TL's report is what
that looks like from outside: *"las transiciones quedan abruptas entre
cambios y llamados de backend"*. Concretely, on `develop` at the commit this
branch was cut from:

| Surface | What happens today | Where |
|---|---|---|
| Holdings, first paint | a bare Material `CircularProgressIndicator` centred in a void | `app/lib/features/holdings/view/holdings_view.dart:31-33` |
| Holdings, `By asset class` / `By sector` | **nothing at all.** The bloc emits the new `groupBy` and awaits the refetch; the view holds the *previous* grouping's ring and rows, so the tapped pill lights up over figures that belong to the other grouping, then they jump | `holdings_bloc.dart:64-82` (no in-flight state), `holdings_view.dart:43-67` |
| Activity, first paint | a bare `CircularProgressIndicator` | `activity_view.dart:28-30` |
| Activity, `All / Buys / Sells / Dividends / Deposits` | **nothing at all.** `ActivityStatus.loading` *is* emitted (`activity_bloc.dart:27-33`) and the view never reads it: the previous filter's rows stay under the new chip, then jump | `activity_view.dart:20-30` |
| Catalog index, first paint | a bare `CircularProgressIndicator` | `catalog_view.dart:32-34` |
| Catalog detail, first paint | a bare `CircularProgressIndicator` | `catalog_detail_view.dart:31-32` |
| Order ticket v1 / v2, first paint | a bare `CircularProgressIndicator`, although each view already holds its component and the component already has a `skeleton()` | `order_ticket_view.dart:40`, `order_ticket_v2_view.dart:41` |

Two of these are worse than merely undesigned. **Holdings' toggle and
Activity's chips leave the previous option's figures on screen under the new
option's label.** That is not a cosmetic gap: for the seconds the request is
in flight, the client is showing a payload under a caption it does not belong
to, which is the one thing this showcase exists to demonstrate the client
never does.

## 2. Scope

**In**

- A loading affordance for all seven rows of the table above, built from the
  0015 vocabulary — no second mechanism.
- Two additions to that vocabulary, both in `app/lib/skeleton/`: `SkeletonRows`
  (a run of equal shimmer blocks — a list that has not arrived) and
  `SkeletonSwitcher` (the cross-fade between a skeleton and what replaces it).
- One in-flight flag on `HoldingsState`, because the tab's existing `status`
  cannot say *"the card is reloading while the list is fine"*.
- The rule that decides skeleton-or-spinner, written down (§3 OD-1) so the
  next wait does not get argued from scratch.

**Out**

- The `By position` / `By asset class` segment on Holdings (§3 OD-6 — it
  issues no request; there is nothing to wait for).
- The Assistant composer, sign-in and the order ticket's in-flight edit: all
  three already carry the right affordance under OD-1 and are unchanged
  (§3 OD-2).
- Any new *colour*. §3 OD-4 records why `SkeletonTokens` grows by nothing.
- Goldens for the two new primitives (§5 says why the four *pages* get them
  and the primitives do not).

## 3. Rulings

- **OD-1 — a skeleton for a surface, a spinner for an action.** This is the
  rule the codebase was already following without saying so, and it now has a
  name because three of the seven rows above were argued individually before
  anyone noticed they were the same question.

  > A **surface** is a region whose *content* is being fetched — a card, a
  > list, a page, a component. Its affordance is a **skeleton**: the shape the
  > content will take, drawn in `SkeletonTokens` grey. It occupies the layout
  > the content will occupy, so nothing reflows when the payload lands.
  >
  > An **action** is a control the person just operated, whose *effect* is in
  > flight — a sign-in button, an order-ticket field being re-rendered. Its
  > affordance is a **spinner**, attached to that control. The surface around
  > it does not change, because it is not what is loading.

  The test between them is *what is uncertain*: if the person is waiting to
  see something, skeleton; if they are waiting for something they did to take,
  spinner. The existing `CircularProgressIndicator` inside
  `sign_in_email_form.dart` and `order_ticket_busy_dot.dart` are actions and
  stay exactly as they are. Every `CircularProgressIndicator` that is a
  *page's* whole body is a surface wearing an action's clothes, and all six
  are replaced here. The one remaining spinner inside a skeleton is
  `SkeletonCaption`'s 11 px ring, which is chrome the artboard draws.

- **OD-2 — the rule is enforced by a test, not by this paragraph.**
  `app/test/architecture/transition_rules_test.dart` asserts that no file
  under `app/lib/features/**/view/` constructs a `CircularProgressIndicator`
  **except** the two allow-listed action sites, by path, in the same shape
  `binding_rules_test.dart` allow-lists the geometry seam. The allow set is
  asserted to have exactly two members that still exist on disk, so deleting
  one of them fails the gate instead of silently widening the rule. A seventh
  page that reaches for a spinner is then a red gate and not a review note —
  which is the whole reason the first six were able to accumulate.

- **OD-3 — skeleton exactly what the option governs, and keep the rest.**
  0015 OD-1 established this for the Home hero (the total stays, the change
  and the sparkline give way) and it generalises:

  | Surface | Kept on screen | Replaced by a skeleton |
  |---|---|---|
  | Holdings, group-by | app bar, total, gain, `Catalog` chip, **the toggle itself**, the position list | the allocation ring; and the class rows, when that list is showing |
  | Activity, kind | app bar, **the chips**, the simulation note | the dated sections |

  The control the person just touched is never the thing that disappears —
  swapping the whole card out would take the toggle with it, so the person
  loses the pill they tapped and cannot tap another. And what is kept is only
  what the option does not govern: `filters[]` and `note` are the same for
  every `kind`, `total` and `gain` are the same for every `group_by`. Anything
  the option *does* govern goes grey rather than staying stale, which is the
  half of this that is a correctness fix (§1) and not a polish one.

- **OD-4 — `SkeletonTokens` grows by nothing, and that is the finding.** Every
  shape added here is built from `SkeletonShimmer`, `SkeletonCaption` and the
  page's existing palette, so all of it reads `SkeletonTokens` already. 0015 §2
  called this out — *"a placeholder has no component identity yet, so what
  differs between them is the shape, never the grey"* — and seven more
  placeholders is the claim holding up. Adding a token nothing needed would
  have made the file describe the app less accurately, not more.

- **OD-5 — the cross-fade's duration is a const on the widget that owns it,
  not a token.** `SkeletonSwitcher.period` sits beside `SkeletonShimmer.period`
  (1.4 s), `SkeletonPulse.period` (700 ms) and `SkeletonCaption.period` (1 s):
  four motion values, one convention, one place a reader looks. Putting this
  one in `SkeletonTokens` would create a *second* home for skeleton durations
  — and "two homes, free to drift" is the defect this repository has written
  down five times in `.claude/rules/ci-conventions.md` §5. It is also
  brightness-invariant, and `SkeletonTokens` is a `ThemeExtension`: it would
  have had to carry the same value in both palettes, which is the shape of a
  thing that does not belong there.

- **OD-6 — the `By position` / `By asset class` segment gets nothing, on
  purpose.** It is the one control in the brief's list that issues **no
  request**: `HoldingsListChanged` re-reads two payloads the tab already
  holds (`holdings_bloc.dart:18-20`). A skeleton there would draw a wait that
  is not happening — the placeholder would be gone in the same frame it
  appeared, which reads as a flicker and tells the person something false
  about how the app works. **An affordance marks a wait; there is no wait
  here.** If that segment ever starts fetching, this ruling is what says to
  revisit it.

  **The cost, stated:** that segment is now the only content change on the
  Holdings tab that is a hard cut while everything around it cross-fades.
  That is consistent — a cut is what an instantaneous change looks like — but
  it is a visible inconsistency and it is accepted here rather than
  discovered later.

- **OD-7 — reduced motion is inherited, not re-decided.** 0015 OD-5 put
  `MediaQuery.disableAnimationsOf` inside each primitive, so every shape built
  out of them rests for free. The one new animation is `SkeletonSwitcher`,
  which reads the same flag and uses `Duration.zero` — the swap is instant and
  correct rather than absent. The rule this sets for anything later: **a new
  skeleton composes the primitives and adds no `AnimationController` of its
  own.** `transition_rules_test.dart` asserts no file under `app/lib/skeleton/`
  outside the three primitives constructs one.

## 4. Acceptance criteria

1. **AC-1** — The Holdings tab before its first payload draws `HoldingsFirstRun`
   (app bar, header card with the component's own ring skeleton, segment,
   position rows), not a `CircularProgressIndicator`.
2. **AC-2** — Tapping `By sector` keeps the app bar, the total, the gain, the
   `Catalog` chip and the toggle on screen with the tapped pill selected, and
   replaces the ring with `HoldingsAllocationSkeleton` until the answer lands.
   `HoldingsState.allocationLoading` is `true` for exactly that interval.
3. **AC-3** — With the `By asset class` list showing, the same tap also
   replaces the class rows with `SkeletonRows`, and the position list is
   untouched when that list is showing instead.
4. **AC-4** — The Activity tab before its first payload draws
   `ActivityFirstRun`, not a `CircularProgressIndicator`.
5. **AC-5** — Tapping a filter chip keeps the app bar, the chips (with the
   tapped one selected) and the note, and replaces the dated sections with
   `SkeletonRows` until the answer lands.
6. **AC-6** — The catalog index and a catalog detail page each draw their own
   board-shaped skeleton while loading, not a `CircularProgressIndicator`.
7. **AC-7** — Both order-ticket views draw their **component's own**
   `skeleton()` before the first payload; the in-flight marker on a field
   (`OrderTicketBusyDot`) and the sign-in button's spinner are unchanged.
8. **AC-8** — No file under `app/lib/features/**/view/` **or
   `app/lib/components/`** constructs a `CircularProgressIndicator` outside
   the two allow-listed action sites, and the allow set has exactly two
   members, both of which exist. (The scope is both directories because one
   of the two legitimate spinners, `order_ticket_busy_dot.dart`, is a
   component rather than a view.)
9. **AC-9** — Under `MediaQuery.disableAnimations` every new shape rests and
   `SkeletonSwitcher` swaps in `Duration.zero`; no new `AnimationController`
   exists outside the three 0015 primitives.
10. **AC-10** — `cd frontend && make gate` is green: 150 lines per file
    including tests, 100 % line coverage per file, layering and manifest
    unchanged.

## 5. Test decision

**Widget tests for behaviour, and six goldens for the four page skeletons.**

Most of what this spec claims is a *shape and a count* — which widget stands
where, how many rows, which control survived the swap — and those are
asserted by type and by count, where a failure names the thing that moved.
0015 made that call and it still holds for the swap logic.

The four page-shaped skeletons are the exception, and OD-8 is why: unlike the
six component skeletons, they were **not** measured off an artboard, so there
is no stylesheet a reviewer could check them against. A count proves how many
blocks there are and nothing about where they sit — and *"the skeleton
occupies the layout the content will occupy, so nothing reflows when the
payload lands"* (OD-1) is the entire point of drawing one. That is the claim
`.claude/rules/frontend/testing.md` §6 keeps goldens for: *a layout that
reflowed*. `transition_goldens_test.dart` therefore captures
`HoldingsFirstRun` and `ActivityFirstRun` in both themes and the two catalog
boards in one, all pumped under reduced motion so the shimmer rests at
mid-sweep and the raster is deterministic. They compare through the tolerant
comparator (ADR-L D-15).

`SkeletonRows` and `SkeletonSwitcher` get no golden: one is a stack of grey
rectangles whose spacing is asserted arithmetically, the other draws nothing
of its own.

| AC | Test |
|---|---|
| AC-1 | `app/test/features/holdings/view/holdings_loading_test.dart` |
| AC-2 | `holdings_bloc_test.dart` (the emission pair), `holdings_loading_test.dart` (the kept chrome, the swapped ring) |
| AC-3 | `holdings_loading_test.dart` |
| AC-4 | `app/test/features/activity/view/activity_loading_test.dart` |
| AC-5 | `activity_loading_test.dart` |
| AC-6 | `app/test/features/catalog/view/catalog_loading_test.dart` |
| AC-7 | `order_ticket_view_test.dart`, `order_ticket_v2_view_test.dart` |
| AC-8, AC-9 | `app/test/architecture/transition_rules_test.dart` — **mutation-checked**: the evidence is in the PR body, per `.claude/rules/frontend/testing.md` §4 |
| AC-9 | `app/test/skeleton/skeleton_switcher_test.dart` (both motion settings) |
| the four page shapes | `app/test/skeleton/transition_goldens_test.dart` — six rasters |
| AC-10 | the gate |

## 6. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-8 | The artboards draw no `Loading · skeleton` state for the Holdings, Activity or Catalog **pages** — only for the six components. The shapes here are therefore composed from the page's own layout rather than measured from a stylesheet, which is a departure from how every other surface in this app was built. | design | Keep them. They print no word design owns and no figure (N-3, N-9); when a page-level artboard arrives, it is measured and these are replaced, the way 0015 §2 measured the component ones. |
| OD-9 | `SkeletonSwitcher` cross-fades in 180 ms. Nothing measured that number — the artboards animate the shimmer, the pulse and the ring, and say nothing about the swap. | design | Keep 180 ms. It is below the 200 ms at which a transition starts reading as a delay rather than as continuity, and it is one const to change. |
