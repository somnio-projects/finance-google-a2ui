---
description: The frontend/ coverage contract, the pump_app harness, and what a test must assert. Complements the synced .claude/rules/flutter/testing.md and bloc-test.md.
paths:
  - "frontend/**/test/**/*.dart"
  - "frontend/tool/check_coverage.dart"
alwaysApply: false
---

# Frontend testing rules

`.claude/rules/flutter/testing.md` and `bloc-test.md` are synced from
`somnio-ai-tools` and still apply in full — matchers, private mocks, `setUp`
inside groups, `'renders $Widget'` interpolation, one scenario per test. This
file adds what is **specific to `frontend/`** and stricter.

## 1. The coverage contract

**100 % line coverage, per file**, over all four packages
(`tool/check_coverage.dart`).

Why not "100 % branch", like the backend: **Dart's coverage tooling emits line
hits only — there is no branch data in lcov for Dart.** The backend contract
cannot be reproduced literally, so this is the strongest honest equivalent. It
is strictly above the `≥ 80 % per file` floor in the synced rule.

The threshold goes **up**, never down, and never in a feature PR. Exemptions
live in `tool/check_coverage.dart` with a written reason each, and there are
two today: generated code, and `lib/main.dart`.

**100 % is not the goal; it is the floor that makes the goal visible.** A test
that executes a line without asserting behaviour is not a test. If reaching a
line needs a contortion, that is usually the code asking to be split — three of
the four coverage gaps found while building this app were closed by extracting
a function (`devTokenProvider`) or deleting dead code (the sealed base's unused
`props`), not by writing a contrived test.

## 2. Where a test lives

Mirror the source tree.

| Source | Test |
|---|---|
| `packages/<p>/lib/src/x.dart` | `packages/<p>/test/src/x_test.dart` (`dart test`) |
| `app/lib/components/<n>/<n>_component.dart` | `app/test/components/<n>/<n>_component_test.dart` |
| `app/lib/features/<f>/bloc/<f>_bloc.dart` | `app/test/features/<f>/bloc/<f>_bloc_test.dart` + `_event_test` + `_state_test` |
| the structural rules themselves | `app/test/architecture/` |

The three pure packages run under **`dart test`** in about a second, which is
the practical payoff of keeping them free of Flutter.

## 3. The harness

`app/test/helpers/pump_app.dart` gives `tester.pumpApp(widget, …)`, which wraps
the subject in the **real theme** and the real providers. Use it for every
widget test: a bare `MaterialApp` would hide a missing `ThemeExtension` or an
unprovided repository, which is exactly the kind of wiring a widget test should
be catching.

Shared fixtures go in a `*_harness.dart` or `fixtures.dart` beside the suite,
not copy-pasted — a fixture that differs between two halves of a class's tests
is how the halves stop agreeing. Extracting one is also the usual fix when a
test file passes 150 lines.

## 4. What a test must assert

- **Behaviour, not execution.** `expect`/`verify` in every test.
- **For a component:** that the `*.display` strings appear **and** that the raw values do not. The second assertion is the one that catches N-4.
- **For a bloc:** the complete state sequence, plus `verify` on the repository call, following the synced `bloc-test.md` shape (`buildBloc()` helper, `setUp` stubs, groups by event).
- **For a failure path:** the failure kind *and* its `code`. Asserting only "it failed" passes when the wrong thing failed.
- **For a structural rule:** mutate it. A layering or budget rule added without watching it turn red is a rule nobody has tested; the four in this app were each mutation-checked and the evidence is in the GGU-91 PR body.

## 5. A component test reads the generated catalog, it does not copy it

`docs/catalog/view-catalog.snapshot.json` is on `develop` (GGU-53), so spec
`frontend/0001` OD-1 is **closed**: `app/test/helpers/catalog_snapshot.dart`
reads it, and a component test binds `exampleFor('<A2UIComponent>')` rather
than a checked-in copy. `app/test/architecture/catalog_contract_test.dart`
additionally asserts that every registered component's view id and A2UI name
are ones the backend publishes — the client half of the defect GGU-53 found,
where four of six component names changed in one commit and a client holding
the old one registers happily, covers to 100 % and shows a placeholder.

A remaining checked-in copy (`app/test/helpers/fixtures.dart`) is labelled as
a fixture. Do not add another silently — a copy of a generated artefact is
the thing that goes stale.

## 6. Goldens prove the raster; the geometry is proved separately

A chart carries two kinds of claim and they need two kinds of check.

- **Geometry is arithmetic** and lives in `packages/finance_charts`, asserted
  against numbers measured from the design. A failure names the bar.
- **A golden** catches what arithmetic cannot: a colour from the wrong
  palette, a missing label, a layout that reflowed. A failure says only that
  something moved.

Keep both. The GGU-55 mutation check changes one scale's target interval
count and watches fourteen geometry assertions **and** three goldens go red
together; either alone would have been a weaker claim.

Goldens compare through the tolerant comparator in
`app/test/flutter_test_config.dart` (ADR-L D-15) — a raster is not portable
across platforms, and a byte-exact golden generated on a laptop is a check
that fails on the Linux runner for a reason that is not a defect. Text in a
golden renders in Flutter's test font, so they prove bars, connectors,
colours and layout, **not** typography.

### The comparator measures two things, and both are calibrated (GGU-106)

The 1.5 % tolerance was chosen from two measurements — a **0.69 %**
cross-platform noise floor and a **4.97 %** smallest real defect — and both
were taken on **opaque bars**. The payoff chart shades half-planes with a
translucent wash, and there the metric means something else: a wash touches
every pixel in its region, so any adjustment to it moves ~all of them by a
trace amount. *"Percentage of pixels that differ at all"* and *"the amount by
which they differ"* are different questions, and translucency makes the first
useless. Measured on this suite under the pinned SDK (spec `frontend/0029` §4):

| change | paint | differ at all | max Δ | differ by > 2/255 |
|---|---|---|---|---|
| re-render, no source change (×14) | both | 0.000 % | 0 | 0.000 % |
| wash alpha .070 → .078 — **invisible** | translucent | **83.893 %** | **2** | **0.000 %** |
| wash at the other artboard's alpha (.070 → .100) | translucent | 85.540 % | 8 | 83.020 % |
| wash alpha .070 → .200 | translucent | 85.627 % | 33 | 85.496 % |
| gain bar in the other artboard's colour | opaque | 2.107 % | 94 | 2.093 % |
| gain bar nudged 2/255 — **invisible** | opaque | 2.029 % | 2 | **0.000 %** |

Read the third column down: it ranks an invisible change **forty times above**
a bar drawn in flatly the wrong colour. So a pixel is now counted only once it
differs by more than `GoldenDifference.amplitudeFloor` (**2/255**, the measured
amplitude of the invisible case and the smallest value that admits it), and the
count is compared with the **unchanged** 1.5 %. Two gates against two kinds of
noise: translucency is many pixels at a trace amplitude, cross-platform
anti-aliasing is few pixels at a large one — and the amplitude floor
deliberately does **not** suppress the second, which is why the area threshold
stays.

Three things to inherit rather than rediscover:

- **The calibration, not the number.** A new threshold needs a noise floor *and*
  a smallest-real-defect, both measured, for the kind of paint it will meet.
  Every invisible case above measures 0.000 % and every real one 2.093 % or
  more; a single bar between them is supported by that separation, not assumed.
- **This is a relaxation, and a one-directional one.** The counted pixels are a
  subset of those counted before, so no golden that is green can turn red. The
  1.5 % itself is untouched and goes **down** as the noise is understood better,
  never up to absorb a failure.
- **A crop is still the right answer for text.** `frontend/0004`'s hairline
  golden stays cropped (0029 OD-8): glyph edges are high-amplitude noise on few
  pixels, which this change does not help with. The two whole-page skeleton
  goldens measure 0.800 % at Δ 231 against their own masters *on the machine
  that renders them* — half the budget spent before CI is involved.

`GoldenDifference` lives in `app/test/helpers/` and has its own suite over
hand-built rasters, because a comparator whose thresholds are only ever
exercised by the goldens that pass is the "never been shown to reject" defect
§7 is about.

## 7. The gate's own scripts have a suite

`frontend/test/tool/` covers `tool/`, and `make test-tool` runs it. It exists
because `check_coverage.dart` used to print `coverage ok — 0 lib file(s)
accounted for` and exit **0** when its directory walk found nothing: every
assertion in it is universally quantified over the files it found, so an
empty set satisfied all of them. A check that cannot report success on an
implausibly small input is the same idiom `repo.spelling` uses
(`.claude/rules/ci-conventions.md` §5), and it belongs on anything that walks
a tree.
