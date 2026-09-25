---
description: Frontend layering, the composition root, the component seam and the 150-line budget for the frontend/ Flutter client. Complements .claude/rules/flutter/ (synced, never edited here).
paths:
  - "frontend/**/*.dart"
  - "frontend/Makefile"
  - "frontend/pubspec.yaml"
  - "frontend/**/pubspec.yaml"
alwaysApply: false
---

# Frontend architecture rules

Enforces [ADR-L](../../../docs/adr/ADR-L-client-architecture.md) for
`frontend/`. These are **this project's** rules; `.claude/rules/flutter/*` is
synced from `somnio-ai-tools` and is never edited here. Where the two differ,
the deviation is argued in ADR-L and repeated in `frontend/CLAUDE.md` — it is
never silent.

> Applies to `frontend/`, which since 2026-09-22 is the only Flutter app in
> this repository. It used to say "`client_flutter/` is a different app with
> different decisions"; that app was retired (spec `repo/0002`) and its four
> rules under `.claude/rules/client/` went with it.

## 1. The layers, and what each may import

```
app/lib/**/view/*_page.dart   owns its bloc's lifetime. MAY read the repository
                              that bloc needs — and that is the only reason.
app/lib/**/view/*_view, _View widgets. Read bloc state. Never a repository.
app/lib/**/bloc/      Bloc. Calls a repository. Never the api client, never http, never a widget.
app/lib/components/   bind a payload to widgets. Import ViewPayload (a type);
                      never read a repository instance; never a feature.
packages/finance_views_repository/   composes the api client. Pure Dart.
packages/finance_api_client/         the ONLY HTTP speaker. Pure Dart.
packages/finance_auth/               session, IdentityProvider seam, AccessGateway,
                                     AuthRepository. Never a widget, never Firebase —
                                     the Firebase implementation lives in app/lib/auth/.
packages/finance_charts/             chart GEOMETRY only: scales, nice ticks,
                                     (steps, size) → rects. Never dart:ui — the painter
                                     that needs it is app/lib/charts/ (ADR-L D-13).
packages/finance_core/               Result, failures, problem details. Depends on nothing.
```

Dependencies point one way, and never skip a layer. **All five** packages are
**pure Dart**, so importing Flutter into them is a compile error rather than a
review note — that is the point of the workspace.

This block listed **three** of the five until GGU-129, which made it a hole in
the rule rather than a stale count: the table that governs what may import what
was silent on `finance_charts` — the package the root `CLAUDE.md` calls out as
load-bearing for the numbers invariant — and on `finance_auth`.

The **page/view split** is the shape `.claude/rules/flutter/architecture.md`
prescribes and its own example uses: a page builds the bloc, so it needs the
repository the bloc takes. A widget that is not a page has no business
holding one — `layering_test.dart::only a page resolves a repository from
the widget tree` allows `context.read<ViewsRepository>()` **only** in a file
named `*_page.dart`, and it is drawn in
[diagram 12](../../../docs/diagrams/12-frontend-layers.md).

Two test files hold all of this, split to stay inside the budget:
`app/test/architecture/layering_test.dart` (imports, the composition root,
the page rule) and `binding_rules_test.dart` (numbers, clock, interpreters,
component registration). Together they are the counterpart of the backend's
`tests/unit/presentation/test_package_boundaries.py`, and they fail on the
*mechanism*: the forbidden import, the stray constructor.
**If you change a rule there, mutate it and watch it go red.** A green check
is evidence only if it could have been red.

## 2. One composition root

`app/lib/bootstrap.dart` constructs every dependency. Nothing else may
construct an `http.Client`, a `FinanceApiClient` or a `ViewsRepository` — the
layering test enforces it by name.

- Dependencies arrive by **constructor injection**; `RepositoryProvider`
  publishes them to the tree. No service locator, no `get_it`, no global.
- A test builds the same tree through `buildApp(viewsRepository: …)` with a
  fake, and never goes near an `http.Client`.
- `AppConfig` is the only reader of `String.fromEnvironment`. Nothing else
  reaches for an ambient value — the Flutter counterpart of "never `os.environ`
  in application code".

## 3. Adding a component edits no existing file

A component is a **directory** under `app/lib/components/<name>/` containing
`<name>_component.dart`, which declares:

- a `ViewComponent` subclass with the frozen `viewId` and its `a2uiComponent`;
- `Widget build(BuildContext, ViewPayload)` that reads paths and renders;
- optionally `Widget skeleton(BuildContext)` — the card drawn in its place
  while the payload is on the way (spec frontend/0015 OD-3). The default is
  the Assistant's generic surface; a component whose design page draws its
  own skeleton overrides it in a `<name>_skeleton.dart` beside the binding;
- exactly one `void register(ComponentRegistry registry)`, at the bottom.

Then `make manifest`. That regenerates `component_manifest.g.dart`, which is
checked in **and** re-rendered and diffed by the gate — the repository's
standing rule for generated artefacts (`ci-conventions.md` §4).

**No enum, no union, no `if/elif`, no shared list is edited.** If adding a
component makes you edit a hand-written file, the seam is wrong: fix the seam,
do not extend the chain (ADR-L D-3, mirroring ADR-K D-15).

A component may create more than one file — the widget usually belongs beside
the binding — and the 150-line budget is a gate while "one file" is a
preference. Name them after the directory so the group is obvious in a listing.

## 3b. A skeleton for a surface, a spinner for an action

Every wait has an affordance and the two are not interchangeable
(spec [frontend/0020](../../../specs/frontend/0020-transition-states.md) OD-1):

- A **surface** is a region whose *content* is being fetched — a card, a list,
  a page, a component. It waits as a **skeleton**: its own shape, in
  `SkeletonTokens` grey, occupying the layout the content will occupy, so
  nothing reflows when the payload lands.
- An **action** is a control the person just operated whose *effect* is in
  flight — the sign-in button, an order-ticket field being re-rendered. It
  waits as a **spinner**, attached to that control; the surface around it does
  not change, because it is not what is loading.

Two consequences that are gate failures rather than review notes
(`app/test/architecture/transition_rules_test.dart`):

- A `CircularProgressIndicator` under `features/**/view/` or `components/**`
  is a **page wearing an action's clothes**. Exactly two files are allowed it,
  by path, and the allow set's size is asserted. Six pages had drifted this
  way before the rule was written, which is why it is a test.
- A new skeleton **composes the 0015 primitives and declares no
  `AnimationController` of its own**. Reduced motion is inherited that way —
  each primitive reads `MediaQuery.disableAnimations` — and an animation
  nobody can turn off is an accessibility defect (0020 OD-7).

When an **option** is what is loading, grey exactly what that option governs
and keep the rest, including the control the person just touched (0020 OD-3).
Leaving the previous option's figures under the new option's label is a
contract violation, not a cosmetic one.

## 4. Errors are values

- Every boundary returns `Result<T>`; `AppFailure` is `sealed`, so a `switch`
  is exhaustive and a new failure kind is a compile error in every incomplete
  handler.
- Nothing throws across a layer. The single exception is
  `PayloadContractException`, thrown by `ViewPayload` inside a component's
  `build` and caught by `ComponentHost`, because a widget tree cannot return a
  `Result`. Do not add a second exception that crosses a boundary.
- A failure shown to a user is the backend's own safe `detail`. Never a library
  message, never a stack trace, never an exception's `toString()`.
- **One narrow exception, and it branches on `code`.** The Assistant's failure
  card (`turn_failure_notice.dart`) shows its own sentence for exactly one
  code, `dependency-unavailable`, because the detail behind it (`model
  provider unavailable`) is written for an operator and was reaching the
  screen in red (GGU-111, spec frontend/0025 OD-4). Every other code shows the
  failure's own `message` — for `transport-unavailable` that is already this
  client's copy, written where the failure happened. Choosing copy by `code`
  is the contract's own rule (`contract-binding.md` §4); choosing it by
  `detail` would not be, and inventing a sentence for a code nobody has met is
  neither.
- **A failure state has a way out.** `TabFailure` and the Assistant's card each
  carry a *Try again* that re-issues the request through the same bloc that
  failed — never a second path (GGU-110/111, spec frontend/0025 OD-2).

## 5. The budget and the documentation

- **≤ 150 lines per file**, sources *and* tests (`tool/check_file_budget.dart`).
  Over budget → split by responsibility. A test file that grows past it usually
  wants its fixture extracted into a harness and its groups split by concern.
- **Every public symbol carries a doc comment** — `public_member_api_docs`,
  fatal under `dart analyze --fatal-infos`. Say *why*, not what the name
  already says.
- Lines ≤ 80 characters; `log()` from `dart:developer`, never `print()`.

## 6. Checklist before the PR

- [ ] `cd frontend && make gate` green.
- [ ] New component: directory + `register`, `make manifest` run, manifest committed.
- [ ] No file over 150 lines; every public symbol documented.
- [ ] Layering test still passes, and any new rule in it was mutation-checked.
- [ ] Deviations from `.claude/rules/flutter/*` argued in ADR-L, not left implicit.
- [ ] Spec updated (`specs/frontend/NNNN-*.md`); ADR-L amended if a ruling changed.
