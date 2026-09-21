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

## 7. The gate's own scripts have a suite

`frontend/test/tool/` covers `tool/`, and `make test-tool` runs it. It exists
because `check_coverage.dart` used to print `coverage ok — 0 lib file(s)
accounted for` and exit **0** when its directory walk found nothing: every
assertion in it is universally quantified over the files it found, so an
empty set satisfied all of them. A check that cannot report success on an
implausibly small input is the same idiom `repo.spelling` uses
(`.claude/rules/ci-conventions.md` §5), and it belongs on anything that walks
a tree.
