---
description: Client testing contract — the coverage bar and who checks it, unit vs widget vs bloc tests, the verbatim-binding test that protects ADR-K, and what a mutation check looks like in Dart. Loads when touching client tests or the app manifest.
paths:
  - "client_flutter/*/test/**/*.dart"
  - "client_flutter/*/pubspec.yaml"
alwaysApply: false
---

# Client testing rules

Baseline: [`.claude/rules/flutter/testing.md`](../flutter/testing.md) and
[`.claude/rules/flutter/bloc-test.md`](../flutter/bloc-test.md). This file adds
what is specific to this repository and corrects what the generic rules assume
about a project layout we do not have.

## 1. The bar, and who actually checks it

**≥ 80 % line coverage per file**, not per project — the generic rule's number
([`flutter/testing.md`](../flutter/testing.md) §Coverage Rule), kept
deliberately rather than raised to the backend's 100 %. The backend earns 100 %
branch coverage because it owns the arithmetic; the client owns almost no
logic, and a 100 % bar over widget trees buys tests that pump a page and assert
nothing.

**No machine checks this number.** `flutter.test` runs
`flutter test --coverage` and `client-ci.yaml` uploads `lcov.info` as an
artifact with 14-day retention — it **asserts no threshold** (both land with
GGU-1, PR #30). So the bar is a review rule, and the reviewer runs:

```bash
cd client_flutter/app && flutter test --coverage && lcov --list coverage/lcov.info
```

`--list`, never `--summary`: a project at 86 % overall with one file at 40 %
passes a summary and violates this rule. Exemptions, per the generic rule:
generated files (`*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`) and
config stubs of three executable lines or fewer.

Every new file under `lib/` lands in the same PR as the test that brings it to
80 %. A threshold assertion in the gate would end the argument; adding it means
editing `.claude/ship-gate.json` and `client-ci.yaml`, both owned by GGU-1.

## 2. Three suites

| Suite | Lives in | Proves | Doubles |
|---|---|---|---|
| unit | `app/test/<mirror of lib>` | pure Dart: config parsing, token `lerp`/`copyWith`, model decoding | none needed |
| widget | `app/test/<feature>/view/` | a real widget tree pumps and renders the values it was given | a fake repository, a seeded Bloc |
| bloc | `app/test/<feature>/bloc/` | the state sequence an event produces | a fake repository |
| e2e | `client_flutter/e2e_test/` | the round trip against a real backend | **none** — it is the real thing |

`app/test/` mirrors `app/lib/src/` path for path, the way
`backend/tests/unit/` mirrors `backend/src/app/`.

**`e2e_test/` does not run in CI and is not expected to.** It needs a live
backend and a Gemini API key, neither of which a pull-request runner has. It is
run by a human before a demo, and a PR that cannot run it says so under
`Test decision:` rather than leaving the reader to wonder.

## 3. Fakes, not mocks

Prefer a hand-written fake over a mock ([`flutter/best-practices.md`](../flutter/best-practices.md)
§Testing). A repository is an interface with three methods; a fake that records
calls and returns canned payloads is more readable than a mock and cannot
drift. Where a mock is genuinely needed, it is private (`_MockLandingRepository`)
per [`flutter/testing.md`](../flutter/testing.md) §Quick Reference.

**Note what is not installed.** `app/pubspec.yaml` declares `flutter_test` and
nothing else under `dev_dependencies` — there is no `bloc_test`, no `mocktail`,
no `checks`. The generic rules assume all three. Until they are added, bloc
tests are written by hand against the Bloc's `stream` with `expectLater` and
`emitsInOrder`, which is perfectly serviceable. Adding them is a change to
`app/pubspec.yaml`, which **GGU-1 (PR #26) owns** — coordinate rather than
editing it in a parallel PR.

## 4. The test that protects ADR-K

Every widget that renders a backend value gets one test asserting the rendered
text is the payload's string **verbatim**:

```dart
testWidgets('renders the display string the backend sent', (tester) async {
  await tester.pumpWidget(wrap(HoldingRow(holding: fakeHolding)));
  expect(find.text(fakeHolding.marketValueDisplay), findsOneWidget);
});
```

The point is the absence of a literal. `expect(find.text('\$1,234.56'), ...)`
passes whether the widget bound the value or formatted it, so it proves
nothing; `find.text(fake.marketValueDisplay)` goes red the moment anyone
inserts a `toStringAsFixed`. This is the only automated protection
[`presentation.md`](presentation.md) has — write it for every payload-bound
widget, not for a representative one.

Give the fake a value that formatting would visibly change (`'\$1,234.56'`,
not `'12'`). A round number makes the test pass under a formatter too.

## 5. Mutation checks in Dart

The backend requires a mutation check when wiring or a security control is
touched ([`backend/testing.md`](../backend/testing.md)) — the same discipline
applies here, and the client has its own version of the "wiring that nothing
tests" hole.

**The procedure:** delete or comment the one line, run the affected tests,
confirm they go **red**, restore, and state it in the PR under
`Test decision:`. A line that can be removed with the suite still green is a
line no test covers, whatever the coverage report says.

Do it when touching:

| The line | What it silently breaks if untested |
|---|---|
| the `Authorization` header write in the connector's mutable header map (ADR-B D-9) | every request goes out unauthenticated and local tests still pass |
| `X-A2A-Extensions` alongside it (ADR-B D-2) | A2UI degrades to a **text** agent — no surfaces, no error |
| `BlocProvider` registration in a page | the feature is unreachable; a widget test that builds the Bloc directly stays green |
| the `ThemeExtension` registration in `ThemeData.extensions` | tokens fall back and nothing fails |
| the `AppConfig` resolution in `main()` | the app silently uses the default backend URL |

The second row is the one to take seriously: ADR-B records that omitting
`X-A2A-Extensions` makes A2UI **silently** fall back. Silent degradation is
exactly what a mutation check catches and coverage does not.

## 6. Conventions

- Test names say the behaviour: `'emits [loading, failure] when the repository throws'`. Use `'renders $WidgetName'`-style interpolation for type names.
- One scenario per test; group by unit, then by event.
- No shared mutable state between tests; build the subject inside the group's `setUp`.
- Run with `flutter test --test-randomize-ordering-seed random` before pushing — ordering dependence is the flake this catches.
- Find widgets by type or by a rendered value, never by a hardcoded `Key` invented for the test.
- Assert the whole state sequence a Bloc emits, not just the last state.
