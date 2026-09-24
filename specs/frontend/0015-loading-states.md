# 0015 — Loading states: the page arrives in its own shape

- **Area:** frontend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [frontend/0011](0011-the-assistant-as-designed.md) OD-2 (the skeleton as a transport state), [frontend/0016](0016-component-catalog-gallery.md) OD-5 (the gallery's loading card), [backend/0026](../backend/0026-the-home-shell.md) §2 (the Home shell), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3, [ADR-K](../../docs/adr/ADR-K-response-shaping.md) N-3/N-9
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Three moments in this client had nothing designed to stand in them, and all
three showed a Material default or a shape borrowed from somewhere else:

- **Home before its first payload** showed a `CircularProgressIndicator` in
  the middle of an empty page. The artboard draws a second hero, `L2 —
  First-run hero · sparkline loading`: the total stays, and where the change
  and the sparkline go there is a shimmer and `Loading last 30 days…` beside
  a turning ring.
- **A range change** swapped the sparkline for nothing at all while the new
  range's figures were fetched — the same moment the artboard's L2 draws.
- **A surface being composed** — in the Assistant transcript (0011 OD-2) and
  in the gallery's `Loading · skeleton` card (0016 OD-5) — always drew the
  Assistant's generic bars-and-pills card, whichever component was coming.
  The catalog pages draw a different skeleton per component: a ring with a
  hole and legend bars for `HoldingsSummary` (`get_holdings()…`), gridlines
  with a dashed line and a `payoff()…` pill for `RiskPayoffChart`, a header
  row and four metric rows for `ScenarioComparison`.

## 2. Measured, not transcribed

Read off the artboards' stylesheets, light and dark. One palette,
`SkeletonTokens`, serves every skeleton: a placeholder has no component
identity yet, so what differs between them is the shape, never the grey.

| token | light | dark | source |
|---|---|---|---|
| `shimmerBase` / `shimmerHighlight` | `#ECE8F2` / `#F7F4FB` | `#191A21` / `#23242C` | `.sk` / `.skd`, 25 %–50 %–75 % stops |
| `bar` | `#E6E2EF` | `#22232B` | the payoff page's `.skel` rects and rules |
| `pill` | `#EEF0F2` | `#1E2028` | the `payoff()…` pill |
| `caption` | `#8A8D96` | `#8A8D96` | the ring and the words beside it |

Motion: the shimmer band sweeps in 1.4 s, linear, forever (`animation: shim
1.4s infinite linear`); the payoff plot breathes to 55 % opacity and back,
ease-in-out (`.skel`); the caption's ring turns once a second. Under the
platform's reduced-motion setting every one of them holds still.

## 3. Decisions

- **OD-1 — the hero keeps what the person has.** While a range's figures are
  on the way, `HomeHero` prints the total and the range strip and gives the
  change line and the sparkline to `HomeHeroLoading`: a 150 × 18 shimmer, the
  52 px sparkline box shimmering, and `Loading…` beside the ring. The bloc
  makes the moment a state — `HomeRangeChanged` emits `HomeStatus.loading`
  and the answer restores `success` — so the view binds a status rather than
  guessing from a null.
- **OD-2 — the first paint is the page's own shape.** Before any payload the
  Home tab is `HomeFirstRun`: header, hero, card, questions and movers, every
  block a shimmer at the size the real one will take. It prints no greeting,
  no label and no figure — none has arrived, and a placeholder word would be
  a word the client made up (N-9). Its one caption is the hero's `Loading…`.
- **OD-3 — a skeleton is the component's own, through the same registry.**
  `ViewComponent` gains `Widget skeleton(BuildContext)`, defaulting to the
  Assistant's generic `SurfaceSkeleton`; a component whose catalog page draws
  its own overrides it in a file beside the binding, so a new skeleton edits
  nothing outside the component's directory (ADR-L D-3).
  `ComponentSkeletonHost` is `ComponentHost`'s counterpart for the moment
  before there is a payload: the same lookup by view id, the generic surface
  when the view is one this build does not render. `SurfacePending` in the
  transcript and `PreviewKind.loading` in the gallery both go through it.
- **OD-4 — a skeleton draws no figure.** It takes no payload and prints
  nothing that could be read as a number: bars, rings, dashes, and the name
  of the tool the agent is waiting on (`get_holdings()…`, `payoff()…`),
  which is chrome the way `Composing UI…` is. The artboard's `Loading last 30
  days…` names the range in the backend's words (`change.period`); those have
  not arrived, so the caption says only `Loading…` (N-9, N-3).
- **OD-5 — motion respects the platform.** Every primitive reads
  `MediaQuery.disableAnimations` and rests: the shimmer band centred, the
  pulse at full opacity, the ring at its start. That is also what lets a test
  pump a skeleton and settle.

## 4. Acceptance

- **AC-1** Home before its first payload shows `HomeFirstRun` and no
  `CircularProgressIndicator` outside the caption's ring; the payload replaces
  it in place.
- **AC-2** Tapping a range keeps the total on screen and shows
  `HomeHeroLoading` until the answer lands; the bloc's in-flight state is
  `HomeStatus.loading`, its answer `HomeStatus.success`.
- **AC-3** A pending `holdings.allocation.v1` surface in the transcript and
  the `Loading · skeleton` card on its gallery page both draw
  `HoldingsAllocationSkeleton`; `payoff.curve.v1` and
  `scenarios.comparison.v1` draw theirs; every other view and every unknown
  view draws `SurfaceSkeleton`.
- **AC-4** No skeleton prints a figure; the only words are the tool names and
  `Loading…`.
- **AC-5** Under `disableAnimations` no skeleton animates.
- **AC-6** Both themes carry `SkeletonTokens` with the measured values.

## 5. Test decision

Widget tests per primitive (sweep, breath, turn, and each one's rest),
per skeleton (shape, count, caption), for the host (own shape · default ·
unknown view), for `HomeFirstRun` and the loading hero, and bloc tests for
the two new emissions. The gallery and transcript suites assert the host
where they asserted the generic card. No golden: the shapes are counted and
measured, which a golden would only repeat with less to say when it fails.
