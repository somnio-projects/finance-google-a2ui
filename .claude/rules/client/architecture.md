---
description: Flutter client layering — the feature slice, what each layer may import, what a Bloc may not do, and the 220-line Dart file budget with its reasoning. Loads when touching client_flutter Dart sources or the client manual.
paths:
  - "client_flutter/*/lib/**/*.dart"
  - "client_flutter/CLAUDE.md"
alwaysApply: false
---

# Client architecture rules

Applies to `client_flutter/`. The seven files in [`.claude/rules/flutter/`](../flutter/)
are generic Somnio guidance synced from `somnio-ai-tools` and are the baseline;
**this file is the project layer and wins where the two disagree.** They were
written against a different repository — one with a `mobile/` root, a
`packages/app_ui` design-system package and an ARB-based i18n setup. None of
those exist here. Where a generic rule names a path this repo does not have,
read it for the principle and apply it to the layout below.

| Generic rule says | Here |
|---|---|
| run from `mobile/` | run from `client_flutter/` (`best-practices.md` §Project-Specific Rules 1) |
| tokens live in `packages/app_ui` | tokens live in `app/lib/src/theme/` (`ui-theming.md` §Project-Specific Rules) |
| strings live in `app_en.arb`, via `context.l10n` | **no i18n layer exists.** The showcase ships English only; adding `flutter_localizations` is its own ticket, not a drive-by |
| data + repository layers live in `packages/` | they live in the feature slice, `features/<f>/repository/` — this is one app, not a package federation (`architecture.md` §Project Organization) |

## 1. The workspace

`client_flutter/` is a Dart **pub workspace** (`pubspec.yaml` → `workspace: [app, e2e_test]`),
so one `flutter pub get` at the root resolves both members and one lockfile
governs them.

| Member | What it is | May depend on |
|---|---|---|
| `app/` | the shipped client | the pinned alpha stack: `genui`, `genui_a2a`, `a2ui_core`, `flutter_bloc` |
| `e2e_test/` | the out-of-process harness that drives a real backend | `app/` by path, plus test-only packages |

`e2e_test/` depends on `app/`. **`app/` never depends on `e2e_test/`.**

## 2. Layers inside `app/lib`

```
main.dart                          barrel: `export 'src/main.dart';` and nothing else
src/main.dart                      composition root — resolves config, builds the theme, runs the app
src/config/                        AppConfig: every --dart-define is read HERE and nowhere else
src/theme/                         ColorScheme + the FinanceTokens ThemeExtension: every colour
src/primitives.dart                shared widget primitives with no feature knowledge
src/features/<feature>/
    view/                          widgets and pages
    bloc/                          Bloc + Event + State
    repository/                    the only code that speaks to the backend or the genui connector
```

Dependencies point one way — `view → bloc → repository → transport` — and a
layer may never reach past the next one down:

| Layer | May import | Must not import |
|---|---|---|
| `view/` | `bloc/` (of its own feature), `theme/`, `primitives.dart`, Flutter | any `repository/`, any HTTP or connector type, another feature's `bloc/` |
| `bloc/` | its feature's `repository/`, `config/`, `dart:async` | `package:flutter/material.dart`, any widget, any connector or HTTP type |
| `repository/` | the connector and HTTP packages, `config/` | any `view/`, any `bloc/`, `package:flutter/material.dart` |
| `config/`, `theme/`, `primitives.dart` | Flutter and the SDK only | anything under `features/` — these are leaves |
| `src/main.dart` | everything below | — it is the composition root, the one place allowed to wire |

Two of these have a specific shape worth naming, because the inherited sample
broke both:

- **A widget that needs data adds an event, not an import.** If a page finds
  itself holding a repository, the missing piece is a state field.
- **A Bloc is not a Flutter object.** `import 'package:flutter/material.dart'`
  inside `bloc/` is the review blocker that catches "I just needed a `Color`"
  and "I just needed `BuildContext`" — both of which mean presentation logic
  has moved into the business layer. A Bloc that needs a colour is deciding
  something a `ThemeExtension` lookup in the widget should decide.

## 3. What a Bloc may and may not do

| May | Must not |
|---|---|
| hold the feature's state and transitions | format a number, a date, a currency or a percentage (see [`presentation.md`](presentation.md)) |
| call **its own** repository | call another feature's repository, or another Bloc |
| map a repository failure onto a failure state | compute a financial figure of any kind |
| carry values the backend already rendered | build a widget, hold a `BuildContext`, or touch `Theme.of` |
| be constructed by its feature's page | be a singleton, or be reached through a global |

States and events are `const`-constructible and compare by value (`props`),
per [`.claude/rules/flutter/bloc-test.md`](../flutter/bloc-test.md) §Rules 7, 9.

## 4. The file budget — 220 lines for Dart

**220 lines**, counting everything in the file, for every `.dart` file under
`client_flutter/*/lib/`. Not 150.

The backend's 150 is calibrated to Python, where one line is usually one
statement. Dart in this workspace is systematically more verbose for reasons
that have nothing to do with a file doing too much:

- `analysis_options.yaml` sets `lines_longer_than_80_chars` and
  `formatter: trailing_commas: preserve`, so `dart format` puts **one widget
  argument per line**. A `Column` whose children Python would express in ten
  lines lands as thirty.
- Every file in this workspace carries the inherited **14-line Apache header**
  before its first import. Under a 150-line budget that is 9 % of the file
  spent before any code.
- A Bloc feature is three files (`_bloc`, `_event`, `_state`) whose combined
  ceremony — constructors, `props`, `copyWith` — is real but not complexity.

And it is measured rather than guessed. Of the twelve Dart files under
`app/lib` today: median **65** lines, tenth-largest 55, second-largest
**128** (`features/login/view/login_page.dart`). Exactly one file exceeds 220
— `features/landing/view/landing_page.dart` at **247** — and it is precisely
the case the budget exists to catch: it hosts the genui surface, owns the
connector's lifecycle *and* renders the error banner. Three responsibilities,
one file.

So 220 is the number at which every file that does one thing fits comfortably,
and the first file that does three does not. A budget that no current file
violates would teach nobody anything; a budget that half of them violate gets
waived in a week.

**Split by responsibility, never by "part 1 / part 2".** For a widget that
means one of:

- a sub-widget extracted to its own file under the same `view/` folder, when a
  chunk of the tree has its own state or its own reason to rebuild;
- a `_build<Section>` on the same class is **not** a split — it moves lines,
  not responsibility, and the file still has three reasons to change;
- the lifecycle (connector setup, subscription, disposal) moved into the Bloc
  or the repository, where it was supposed to live;
- a pure layout helper moved to `primitives.dart` when two features need it.

**Nothing enforces this today.** `dart analyze` has no file-length rule and
`.claude/ship-gate.json` has no client budget entry. It is a review rule, and
the `backend-reviewer` agent does not read Dart. What *would* enforce it is a
`client_flutter/tool/check_budget.sh` plus a `client.budget` entry in
`ship-gate.json` — deliberately not added here, because the Flutter half of
`ship-gate.json` is owned by GGU-1 (PR #30) and a second PR editing it would
collide. Whoever picks that up: the budget is the number above, and the
existing `check_tokens.sh` / `check_config.sh` are the shape to copy.

## 5. What is actually enforced, and by what

Honesty about the gate matters more here than anywhere else, because the
client's gate is younger than the backend's.

| Rule | Enforced by | Status |
|---|---|---|
| Formatting is canonical | `dart.format` — `dart format --output=none --set-exit-if-changed .` | lands with GGU-1 (PR #30) |
| Strict casts, inference, raw types; no analyzer info or warning | `dart.analyze` — `dart analyze --fatal-infos --fatal-warnings` | lands with GGU-1 (PR #30) |
| No colour literal outside `theme/` | `client.tokens` — `bash tool/check_tokens.sh` | lands with GGU-1 (PR #30) |
| No endpoint URL outside `config/` | `client.config` — `bash tool/check_config.sh` | lands with GGU-1 (PR #30) |
| The suite passes | `flutter.test` — `flutter test --coverage` | lands with GGU-1 (PR #30) |
| The release web bundle compiles | `flutter.web` — `flutter build web --release` | lands with GGU-1 (PR #30) |
| **Layer import direction (§2)** | nothing | **review only** |
| **The 220-line budget (§4)** | nothing | **review only** |
| **Bloc has no Flutter import (§3)** | nothing | **review only** |

The four rows marked *review only* are real rules and are not pretending to be
checks. Each is a one-grep test away from being enforced; none of those greps
can be written in this PR without editing files GGU-1 owns.

## 6. When a request does not fit

A page that seems to need a repository, a Bloc that seems to need a `Color`, or
a widget that seems to need to do arithmetic on a payload is a design problem,
not a rule problem. Extract the sub-widget, add the state field, or — most
often, and see [`presentation.md`](presentation.md) — ask the backend for a
projection that already carries the value. Record the decision in
`specs/client/NNNN-*.md` rather than in a comment.
