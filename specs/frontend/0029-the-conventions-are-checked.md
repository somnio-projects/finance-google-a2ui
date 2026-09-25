# 0029 — The conventions are checked

- **Area:** repository (spec numbering) and frontend (the colour rule, the golden comparator)
- **Status:** In progress
- **Tickets:** [GGU-105](https://somniosoftware.atlassian.net/browse/GGU-105) (spec numbering · the Color-in-lib rule) · [GGU-106](https://somniosoftware.atlassian.net/browse/GGU-106) (the golden tolerance)
- **Also:** [`.claude/rules/ci-conventions.md`](../../.claude/rules/ci-conventions.md) §5 (the three questions), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3 (adding a component edits no existing file) and D-15 (the tolerant comparator), [`frontend/0004`](0004-scenario-comparison.md) OD-6 (which reported the rotted colour claim), [`frontend/0030`](0030-a2ui-agent-path.md) (renumbered here)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

Three conventions, one shape. Each is written down somewhere a reader will
find it, each is true today because somebody remembered, and **nothing fails
when one is broken**. This repository's recurring finding, stated once more:
*a property written down and enforced by nothing is not a property.*

**GGU-105 · Spec numbering.** `specs/README.md` says *"Numbers are per area,
zero-padded, never reused"* and *"One row per file … so a missing spec and a
duplicated one are both visible at a glance."* On `develop`, at the moment this
was written, **two files were numbered `frontend/0002`** and **nine spec files
had no index row at all** — including both halves of the collision. Neither was
visible at a glance to anyone. Earlier, GGU-57 and GGU-59 both wrote
`specs/frontend/0003-*` from branches cut at the same commit, and GGU-59
renumbered afterwards at a cost of a rename plus twenty-one citations.

The cause is structural rather than careless. `sdd.md` says `NNNN` is *"the
next free number"*, and *free* is evaluated at the branch point: two branches
cut from one commit always choose the same number.

**GGU-105 · The Color-in-lib rule.** `frontend/CLAUDE.md` says colour literals
live in a `*_tokens.dart` and nowhere else. Four files in `app/lib/` each
claimed to be **the** one — `chart_tokens.dart`, `chart_palette.dart`,
`allocation_palette.dart` and `payoff_tokens.dart` — and all four sentences
were false. Twenty-one files named a `Color`; five of them were widgets.

The rot was not carelessness either: ADR-L D-3 forbids editing a shared file to
add a component, so each new design-bound surface correctly brought its own
token file. Two agents reached that answer in the same week without conferring.
**The seam was working and the sentence describing it was not** — and GGU-57's
fix replaced one unenforced sentence with another, which resets the clock
rather than stopping it.

**GGU-106 · The golden tolerance.** `flutter_test_config.dart` compares a
golden by *the fraction of pixels that differ at all*, against a 1.5 %
threshold chosen from two measurements — a 0.69 % cross-platform noise floor
and a 4.97 % smallest real defect. Both were taken on **opaque bars**. The
payoff chart shades half-planes with a translucent wash, and a wash touches
every pixel in its region, so the metric saturates on a change nobody can see.
The threshold is not wrong; **the reasoning behind it is narrower than its
use**, and two components have already had to work around the comparator
rather than trust it.

## 2. Rulings

- **OD-1 — spec numbering gets a check, not a scheme change.** `repo.spec-numbers`
  (`scripts/check_spec_numbers.sh`) asserts three properties: the filename is
  `NNNN-lowercase-kebab-slug.md`; no two specs in an area share a number, and
  the failure **names both files**; every tracked spec has exactly one row in
  `specs/README.md`, and every row resolves to a tracked file. A number cannot
  be *allocated* without a shared authority, so the check does not try — it
  makes the collision fail the build instead of surviving the merge. GGU-105
  puts a scheme change explicitly out of scope and this agrees.

- **OD-2 — the spec that keeps `0002` is the one the corpus cites by bare
  number, and it is measured, not argued.** Both files merged on 2026-09-21,
  `0002-a2ui-agent-path.md` first (PR #65, an ancestor of PR #68). Chronology
  was the obvious tie-break and it is the **wrong** one here: twenty citations
  of `frontend/0002` — in nine Dart files, in `frontend/SECURITY.md` and in six
  sibling specs — are bare numbers, and every one of them means
  *chart-primitives*; all five citations of *a2ui-agent-path* already carry its
  slug. Moving the chart spec would have rewritten twenty bare citations a
  reader cannot verify; moving the other rewrote five explicit ones. So
  `0002-a2ui-agent-path.md` became [`0030`](0030-a2ui-agent-path.md), with a
  banner in its own heading, and every citation was followed.

  | which spec moves | citations to follow | bare (unverifiable) citations broken |
  |---|---|---|
  | `0002-chart-primitives-and-waterfall.md` | 25 | **20** |
  | `0002-a2ui-agent-path.md` ← **chosen** | 5 | **0** |

- **OD-3 — it took `0030`, not the lowest free number.** `frontend/0027` and
  `0028` were free; the renumbering deliberately went **above** this spec's own
  `0029`, because two other branches are in flight and will each take "the next
  free number" evaluated at their own branch point — which is the defect this
  spec exists to close, and it would have been embarrassing to reproduce it
  while resolving it. Gaps are therefore explicitly **not** a failure: the check
  asserts uniqueness, not contiguity, the same way `docs/diagrams/` keeps `11`
  free on purpose.

- **OD-4 — the colour rule is a naming convention, never a path list.** A path
  allow-list would have to be edited every time a component is added, which is
  exactly what ADR-L D-3 forbids: the check would *be* the seam violation it
  protects. So `<anything>_tokens.dart` and `<anything>_palettes.dart` may name
  a colour and nothing else may, asserted by
  `app/test/architecture/color_rules_test.dart` against four literal forms
  (`Color(0x`, `Color.fromARGB(`, `Color.fromRGBO(`, `Color.from(`). The
  exception set is **empty and asserted empty**; the suffix set's *size* is
  asserted, the idiom `speech_rules_test.dart` uses for the browser seam.

  Six files were outside the convention and all six moved rather than being
  allow-listed. An allow-list was cheaper and was rejected: the only thing
  qualifying any of them was that nobody had moved them yet, and *"it was here
  first"* is the justification this repository keeps finding at the bottom of a
  rotted rule.

  | file | value | new home |
  |---|---|---|
  | `holdings_toggle.dart` | `0x14000000` pill shadow | `HoldingsTokens.toggleShadow` |
  | `position_tile.dart` | `0x2E4F5DFF` expanded glow | `HoldingsTokens.expandedGlow` |
  | `position_ask.dart` | the indigo icon gradient | `HoldingsTokens.askIconGradient` |
  | `sign_in_hero.dart` | `0x8C4F5DFF` logo glow | `LoginTokens.logoGlow` |
  | `sign_in_google_button.dart` | Google's four brand colours | `LoginTokens.googleMark` |
  | `theme/app_colors.dart` | 21 measured surface values | renamed `app_color_tokens.dart` |

  All five widget values are artboard-independent, so they are `static const`s
  on the token class — the shape `LoginTokens.logoGradient` already had —
  rather than new `ThemeExtension` fields, which would have cost a constructor
  parameter, a field, a `copyWith` and a `lerp` entry each and pushed both files
  over the 150-line budget.

- **OD-5 — `Colors.white` is out of scope, and the number is recorded so the
  next person inherits a measurement rather than a silence.** Nine occurrences
  in four widget files (`home_header.dart`, `home_questions_rail.dart`,
  `sign_in_hero.dart`, `skeleton_caption.dart`), plus one `Colors.transparent`.
  A *named* Material constant is not a colour literal, which is what both
  `frontend/CLAUDE.md` and GGU-105 AC-3 name; and moving them is a **design**
  question — whether that white should follow the scheme in dark mode — not a
  file-location one. Widening the check to `Colors.` today would either force
  nine visual decisions into a harness PR or require nine allow-list entries.
  Left for a ticket; the check is one needle away when somebody makes the call.

- **OD-6 — the golden comparator measures amplitude as well as area, and that
  is the fix rather than a second threshold.** GGU-106 offered three options: a
  per-golden tolerance the test declares, a perceptual comparator, or a
  documented second threshold for translucent surfaces. The first two are
  rejected and the third is *unimplementable as stated*:

  - **A per-golden tolerance is an unchecked claim per test** — precisely the
    defect class GGU-105 is about. Nothing could tell a number chosen from a
    measurement from a number raised until a run went green.
  - **A second threshold for translucent surfaces needs to know a golden is
    translucent**, and the only thing that could say so is a hand-written
    declaration on each test. Same defect, with an extra step.
  - **A perceptual metric (CIEDE2000 or similar) is a dependency and a much
    larger claim** than the evidence supports; it would also need its own
    calibration, and the measurements below already separate the cases
    completely.

  So a pixel is counted only when some channel differs by more than
  `amplitudeFloor` = **2/255**, and that count is compared with the **unchanged**
  1.5 %. Two gates, each against its own noise: translucency is many pixels at a
  trace amplitude, cross-platform anti-aliasing is few pixels at a large one.

- **OD-7 — this is a relaxation, it is said so plainly, and it is provably
  safe for work in flight.** `frontend/CLAUDE.md` says thresholds go up, never
  down; for a *tolerance* the strict direction is down, and the 1.5 % is not
  moved in either direction. What changes is the population measured, and the
  set of counted pixels is a **subset** of the set counted before — so
  `newFraction ≤ oldFraction` for every raster, and **no golden that is green
  today can turn red**. That is the property the branches redesigning the
  waterfall (GGU-115) and the tax-lot table (GGU-116) need: a regenerated
  golden is byte-identical to its render and passes either way, and this change
  cannot fail one of theirs for a reason that is not a regression.

  What it *does* admit is any change of at most 2/255 per channel, on **any**
  paint — the relaxation is amplitude-based and therefore uniform, not
  translucency-specific. Measured cost on the opaque case: a bar drawn in flatly
  the wrong colour reads **2.107 % → 2.093 %**, a loss of 0.014 pp, because a
  real recolour moves pixels by tens of units and only the anti-aliased edge sits
  under the floor.

- **OD-8 — GGU-59's hairline crop stays, and the measurement says why.**
  GGU-106 AC-5 asks that the crop be revisited once the comparator is
  informative. It was, and it is kept: the crop was a workaround for **glyph
  and edge noise**, which is high-amplitude on few pixels and which the
  amplitude floor deliberately does *not* suppress. The comparator is no more
  informative about text than it was. The evidence is in the corpus — the two
  whole-page skeleton goldens (`catalog_index_loading`, `catalog_detail_loading`)
  measure **0.800 % of pixels differing at max Δ 231** against their checked-in
  masters *on the machine that renders them*, before any cross-platform noise.
  A whole-card golden would start at half its budget. Widening the crop would
  trade a check that works for one that is flaky.

- **OD-9 — those two skeleton goldens are reported, not regenerated.** The
  0.800 %/Δ231 above is a real difference against `develop`, not noise, and it
  passes today and still passes after this change (0.799 % under the amplitude
  floor, well inside 1.5 %). Regenerating them here would erase the evidence of
  whatever produced it inside a harness PR that has no business changing what
  the app looks like. Recorded for a ticket; the numbers are in §4.

- **OD-10 — both checks are wired where §5 says, and answer its three
  questions.** Spec numbering is repository-wide — there is no directory it does
  not apply to — so it is `repo.*`, in `repo-ci.yaml`, which carries no `paths:`
  filter. The colour rule proves one stack, so it is a `flutter test` under
  `frontend.test`, beside the four architecture tests that already fail on a
  mechanism, and needs no new gate entry.

  | § 5 question | `repo.spec-numbers` | the colour rule |
  |---|---|---|
  | **1. Same command both halves?** | `bash scripts/check_spec_numbers.sh` and `bash scripts/tests/test_check_spec_numbers.sh`, verbatim in `ship-gate.json`, `repo-ci.yaml` and `.pre-commit-config.yaml` — checked by `repo.gate-pairs` | it is a test file inside `frontend.test` (`make test`), which is one command on both halves for the same reason `py.quality` is |
  | **2. Does it cover what its name claims?** | it claims *numbered once and indexed once*, not *never reused* — see OD-11 | it claims *colour **literals***, not `Colors.white` — OD-5 names the gap and counts it |
  | **3. Under what does it run?** | `bash` + `git ls-files` + `jq`-free; no version-sensitive tool, and the suite builds its own throwaway repositories | the pinned SDK from `frontend/.fvmrc`, proved by `frontend.toolchain` before any other frontend step (GGU-94) |

- **OD-11 — "never reused" is left to people, and that is a decision, not an
  omission.** In git history a renumbering is a delete plus an add, which is
  byte-for-byte what a reuse looks like; a history-based check would have failed
  on GGU-59's own legitimate rename, and on OD-2's. What protects the property
  instead is the index rule: `specs/README.md` keeps a superseded spec's file
  *and* its row, so a number in use stays visible, and the check enforces that
  every file has a row. Recorded here rather than left as a silent gap.

- **OD-12 — the index's ordering claim was removed rather than enforced.**
  `specs/README.md` claimed the table was "ordered by area then number"; it was
  not, and had not been for a long time. Enforcing it means reordering seventy
  rows inside a pull request about enforcement, and ordering is a reading
  convenience rather than an invariant — a collision fails whatever the row
  order is. The sentence is gone. **A claim this file cannot keep is what
  GGU-105 was cut for**, so removing it is the fix, not a retreat from one.

## 3. Acceptance criteria

**GGU-105**

- **AC-1** — a check fails when two files in a `specs/<area>/` directory share a numeric prefix, and names **both** filenames. Its `cmd` is copied verbatim into `.claude/ship-gate.json` under `repo.*` and into `repo-ci.yaml` and `.pre-commit-config.yaml`.
- **AC-2** — the existing `frontend/0002` collision is resolved and every reference followed: the spec heading, the index, `NOTICE`, three sibling specs and four places in `.claude/harness-log.md`.
- **AC-3** — a test enforces the Color rule under `app/lib/` against an expected file set and fails with the offending path; `packages/` is asserted to name no colour at all.
- **AC-4** — both are mutation-checked, in both directions, with the output pasted in the PR.
- **AC-5** — `cd frontend && make gate`, `bash scripts/check_gate_pairs.sh` and `bash scripts/check_spelling.sh` green.
- **AC-6** — every spec file has exactly one index row, and every index row a file. Nine files had none.

**GGU-106**

- **AC-7** — the comparator reports a measure that is meaningful for translucent paint: the fraction of pixels differing by **more than 2/255**, beside the old fraction and the largest channel delta, all three printed on failure.
- **AC-8** — recalibrated on both cases, with a noise figure and a smallest-real-defect for opaque **and** for translucent paint (§4). One threshold covers both **because the measurements separate the cases completely**, not by assumption.
- **AC-9** — mutation-checked: a 2/255 change to a translucent region passes, a visible change to the same region fails and names the file, and an opaque defect still fails.
- **AC-10** — `.claude/rules/frontend/testing.md` §6 records the calibration and the reasoning, so the next person inherits the measurement rather than the number.
- **AC-11** — GGU-59's crop is revisited and the decision recorded with its measurement (OD-8).

## 4. The measurements

Every figure produced on this branch, Flutter 3.47.5 / Dart 3.13.4, macOS
arm64, `flutter test` under the pinned SDK. `fraction` is what the old
comparator reported; `> 2/255` is what the new one reports.

| change | paint | fraction | max Δ | > 2/255 | old | new |
|---|---|---|---|---|---|---|
| re-render, no source change (14 of 16 goldens) | both | 0.000 % | 0 | 0.000 % | pass | pass |
| `catalog_*_loading` against their masters (OD-9) | opaque | 0.800 % | 231 | 0.799 % | pass | pass |
| wash alpha .070 → .078 — **invisible**, 2/255 composited | translucent | **83.893 %** | **2** | **0.000 %** | **FAIL** | **pass** |
| wash at the other artboard's alpha (.070 → .100) | translucent | 85.540 % | 8 | **83.020 %** | FAIL | **FAIL** |
| wash alpha .070 → .200 | translucent | 85.627 % | 33 | 85.496 % | FAIL | **FAIL** |
| gain bar in the other artboard's colour | opaque | 2.107 % | 94 | **2.093 %** | FAIL | **FAIL** |
| gain bar nudged 2/255 — **invisible** | opaque | 2.029 % | 2 | **0.000 %** | FAIL | pass |

Read as the calibration GGU-106 AC-2 asks for:

| | noise floor (same machine) | smallest real defect |
|---|---|---|
| **opaque** | 0.000 % / Δ 0 unchanged; Δ 2 recolour → 0.000 % | wrong artboard colour → **2.093 %** at Δ 94 |
| **translucent** | Δ 2 wash nudge → **0.000 %** | wrong artboard wash → **83.020 %** at Δ 8 |
| cross-platform (macOS → Linux) | **0.69 %**, inherited — see *Not run* | 4.97 %, inherited |

The single threshold covers both because there is no overlap: every invisible
case measures **0.000 %** and every real one **2.093 % or more**, with the
1.5 % bar between them. The nearest miss is the opaque wrong-colour bar at
1.4× the bar, which is the same margin it had before this change (2.107 %) —
the amplitude floor costs it 0.014 pp.

The first metric, read down the table, ranks an **invisible** change (83.9 %)
forty times above a bar drawn in flatly the **wrong colour** (2.1 %). That is
the ticket's point restated as data: this was never a threshold problem.

## 5. Test plan

| AC | How |
|---|---|
| AC-1 | `scripts/tests/test_check_spec_numbers.sh`: a fixture tree with two `0002`s exits 1 naming both files. Plus the live mutation in the PR body. |
| AC-2 | `bash scripts/check_spec_numbers.sh` green on this repository — the suite's last case — and `grep -r "frontend/0002"` resolves to one spec. |
| AC-3 | `app/test/architecture/color_rules_test.dart::only a *_tokens.dart or *_palettes.dart names a Color`, and `::a pure-Dart package names no Color at all`. |
| AC-4 | The suite's nine rejection cases; the two Dart mutations pasted in the PR. |
| AC-5 | The `Verification` block. |
| AC-6 | The same check's index rules, with a fixture for each direction (no row / orphan row / two rows). |
| AC-7 | `app/test/helpers/golden_difference_test.dart` — seven cases over hand-built rasters, including the boundary at `amplitudeFloor + 1` and the empty buffer. |
| AC-8 | §4, and the table repeated in `flutter_test_config.dart`'s own doc comment. |
| AC-9 | Three live mutations against the real goldens, pasted in the PR. |
| AC-10 | `.claude/rules/frontend/testing.md` §6. |
| AC-11 | OD-8, with the `catalog_*_loading` figures as its evidence. |

**Anti-vacuity, in all three checks.** `check_spec_numbers.sh` refuses to
report success on fewer than 40 specs, on an index it cannot parse, or on an
area that has quietly emptied; `color_rules_test.dart` asserts at least 15
colour-naming files were found, and that the suffix set has exactly two
members; `golden_difference_test.dart` asserts an empty buffer is *not* within
tolerance, because a `0/0` fraction is a `NaN` that compares false against
every threshold. All three are the failure mode `check_coverage.dart` and
`repo.spelling` each shipped with.

## 6. Out of scope

- **Changing the spec-numbering scheme** (GGU-105 says so explicitly). Sequential numbers are fine; they needed a check.
- **Reordering the spec index** — OD-12.
- **A history-based "never reused" check** — OD-11.
- **`Colors.white` and other named Material constants** — OD-5, with the count.
- **Raising the 1.5 % tolerance** (GGU-106 says so explicitly). It is untouched; OD-7 states what *is* relaxed and proves the relaxation is one-directional.
- **Regenerating the two stale skeleton goldens** — OD-9.
- **Widening GGU-59's crop** — OD-8, declined with its measurement.
