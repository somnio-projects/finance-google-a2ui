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

## 5. Fixtures are labelled, not trusted

Until `docs/catalog/view-catalog.snapshot.json` lands on `develop` (PR #45),
component tests bind a **checked-in copy** of the catalog's rendered example.
Every such copy carries a doc comment saying it is a fixture and naming the
open decision that replaces it (spec `frontend/0001` OD-1). Do not add a new
one silently — a copy of a generated contract is the thing that goes stale.
