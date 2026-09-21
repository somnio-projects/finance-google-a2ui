# ADR-L — The `frontend/` client architecture

- **Status:** **Proposed** — awaiting TL ratification
- **Gates:** GGU-91 and every later `frontend/` ticket
- **Scope:** `frontend/` only. `client_flutter/` is a separate app and keeps its own decisions, including [ADR-I](ADR-I-client-routing.md).
- **Related:** [ADR-K](ADR-K-response-shaping.md) (the payloads this client binds), [ADR-E](ADR-E-money-representation.md) (money), [ADR-I](ADR-I-client-routing.md) (amended for this app by D-5), [ADR-B](ADR-B-auth-credential-contract.md) (the credential this client will carry), `specs/frontend/0001-frontend-skeleton.md`, `specs/client/0003-client-backend-contract.md`

## Context

> **In the context of** a second Flutter client, built from scratch because the
> first is still largely the upstream restaurant-finder sample and is moving
> slowly, **facing** a backend that already shapes every payload and a
> repository whose backend half enforces its standards with tests rather than
> review notes, **we decided** to build a four-package pub workspace with
> layering enforced by compilation and by a boundary test, a single composition
> root, and a component seam where adding a view edits no existing file, **and
> neglected** a single-package app, generated DTOs per view, and a
> service-locator, **to achieve** a skeleton whose rules cannot be forgotten
> because the gate holds them, **accepting that** four packages is more
> ceremony than a small app needs on day one, and that the payload reader is
> dynamically typed where a generated DTO would be statically typed.

The alternative everyone reaches for first is one Flutter package with folders
for layers. Folders are a convention; a reviewer has to remember them. The cost
of the workspace buys the same rule as a **compile error**: a pure-Dart package
cannot import Flutter, and that is not a rule anybody enforces.

## Decision

- **D-1 — Four packages, layered, dependencies pointing one way.** `finance_core` (Result, failures, RFC 9457) ← `finance_api_client` (the only HTTP speaker) ← `finance_views_repository` (envelope, payload reader, ETag cache) ← `app` (Bloc + widgets). The first three are pure Dart. This is the four-layer shape `.claude/rules/flutter/architecture.md` prescribes, with the layers made into packages so the boundary is mechanical.
- **D-2 — One composition root.** `app/lib/bootstrap.dart` constructs every dependency; nothing else constructs an `http.Client`, a `FinanceApiClient` or a `ViewsRepository`. The analogue of the backend's `bootstrap.py`, enforced by `layering_test.dart` rather than by habit. Dependency injection is **constructor injection plus `RepositoryProvider`** — no service locator (`get_it`) and no `riverpod`, because a locator makes the graph discoverable only at runtime and this codebase's whole argument is that structure should be checkable.
- **D-3 — Adding a component edits no existing file.** A component is a directory under `app/lib/components/` holding a `ViewComponent` that declares its own frozen `viewId` and exposes one `register(ComponentRegistry)`. The wiring lives in a **generated** `component_manifest.g.dart`, re-rendered and diffed by the gate. No enum, no union, no `if/elif`, no shared list. This is ADR-K D-15 held on the client side, and it is checked: `layering_test.dart` requires exactly one `register(` per component module, and `make manifest-check` fails on a stale manifest.
  - *Why generated rather than hand-edited:* Dart has no runtime reflection on the web, so an unimported library is tree-shaken and its registration never runs — a component **must** be imported somewhere. Generating that one file is what keeps "edits no existing file" literally true, and the repository already has the pattern for gating a generated artefact (`.claude/rules/ci-conventions.md` §4).
- **D-4 — No generated DTOs; payloads are read by path.** `ViewPayload.text('total.amount.display')` rather than a `@JsonSerializable` class per view. **This is a deliberate deviation from `.claude/rules/flutter/code-patterns.md`**, which prescribes `json_serializable`. The reason is GGU-41's lesson, verbatim: the frozen contract is *generated* from the backend's registry, and a hand-copied inventory is the one that goes stale. Six views carry 16–49 fields each; a Dart transcription of them is ~170 field names that no gate compares against the backend. A reader that fails loudly on a missing path enforces the same contract without duplicating it, and the failure names the path so it can be raised (N-3).
  - *Accepted cost:* a typo in a path is a runtime failure, not a compile error. It is mitigated by the component's own test binding the catalog's rendered example, and it is **fully closed** by the follow-up in spec `frontend/0001` OD-1, which reads `docs/catalog/view-catalog.snapshot.json` directly once PR #45 lands.
  - *Narrow scope:* this is about **payloads**. A future request body with many fields is a normal DTO, and `json_serializable` is then the project's choice and a one-package addition.
- **D-5 — `go_router`, amending ADR-I for this app.** ADR-I chose imperative `Navigator` for `client_flutter/` because adopting a router there meant rewriting existing navigation for no present need, and it recorded that as a deviation from `code-patterns.md`. This app has no navigation to rewrite, is web-first, and wants shareable URLs and browser back/forward from the first screen, so the trade-off inverts. ADR-I D-4 asked that re-adopting `go_router` be an amendment rather than a rediscovery; this is it. ADR-I D-3 still binds: the auth gate is **one** `redirect`, never a check inside a feature.
- **D-6 — `package:http`, not `dio`.** The official client, minimal surface, and it ships `MockClient`, so the whole transport is tested without a socket. `dio` buys interceptors and retry policy this client does not yet need, and its own `Response` type would have to be kept out of the layers above anyway. Revisit when a real retry policy lands (ADR-B D-7's force-refresh-once).
- **D-7 — Bloc for state.** The repository already carries `.claude/rules/flutter/bloc-test.md` and `architecture.md`; **no deviation is proposed**. Events and states are `Equatable`, states use the getter-parameter `copyWith` so "leave it" and "clear it" are different calls.
- **D-8 — Failure is a value, and the union is sealed.** Boundaries return `Result<T>`; `AppFailure` is `sealed` with `TransportFailure`, `ProblemFailure` and `ContractFailure`, so a `switch` is exhaustive and adding a kind is a compile error in every incomplete handler. Nothing throws across a layer. The one exception is `PayloadContractException`, thrown inside a component's `build` and caught by the single `ComponentHost`, because a widget tree cannot return a `Result`.
- **D-9 — The numbers rule is a test, not a note.** `NumberFormat`, `package:intl`, `dart:math`, `toStringAsFixed`, `double.parse` and `DateTime.now()` are absent from `lib/`, and `layering_test.dart` fails on the mechanism. `ViewPayload` deliberately exposes no numeric accessor: the absence of the tool is what makes the rule cheap to keep (ADR-E, ADR-K D-5, spec `client/0003` N-1/N-2/N-13).
- **D-10 — Two `very_good_analysis` rules are switched off in `analysis_options.yaml`, with reasons.** `unnecessary_type_name_in_constructor` rewrites `const Foo(…)` into Dart 3.13's two-month-old `const new(…)` shorthand; `prefer_initializing_formals` wants `required this._apiClient`, which makes the call site `ViewsRepository(_apiClient: …)` and leaks a private name into the public API. Turning a lint off in that file is a team decision recorded here; scattering `// ignore:` comments is not.
- **D-11 — 100 % line coverage per file, not per project.** Dart's lcov carries **no branch data**, so the backend's 100 % *branch* contract cannot be reproduced literally; this is the strongest honest equivalent, and it is strictly above the `≥ 80 %` floor in `.claude/rules/flutter/testing.md`. Exemptions live in `tool/check_coverage.dart` with a reason each, and are today: generated code, and `lib/main.dart` (three lines whose only statement is `runApp(bootstrap())`; executing it in a test starts the real app and opens a socket).
- **D-12 — The SDK is pinned, and the lockfile is enforced.** `pubspec.yaml` floors at Dart `^3.13.0`, `frontend-ci.yaml` pins Flutter `3.47.5`, and every install is `flutter pub get --enforce-lockfile`. Plain `pub get` silently re-resolves; the strict flag fails instead of quietly changing the dependency graph.

## Consequences

**Positive.** The layering, the composition root, the numbers rule and the
component seam are all held by the gate, so a reviewer spends attention on
behaviour. A pure-Dart core runs under `dart test` in under a second. Adding
the six real components is additive by construction, and so is the seventh.

**Negative / accepted.** Four packages and one generated file are more ceremony
than a one-screen app needs today; the bet is that six components and a gallery
arrive shortly. The payload reader trades compile-time field checking for not
duplicating a generated contract — D-4 names the mitigation and the follow-up
that closes it.

**Known limit — the contract is bound to fixtures until PR #45 merges.** The
component tests bind a copy of the catalog's rendered example, checked in under
`test/`. That copy is a fixture, not a source of truth, and it can drift from
the backend exactly the way D-4 argues against. It is deliberate and temporary:
`docs/catalog/view-catalog.snapshot.json` does not exist on `develop` yet.
Spec `frontend/0001` OD-1 carries the owner and the default.

**Neglected alternatives.**
- *One Flutter package with layer folders*: less ceremony, but the layer boundary becomes a convention a reviewer must remember, which is the failure mode this repository's backend half exists to avoid.
- *`get_it` / `riverpod`*: both work; both make the dependency graph a runtime lookup rather than a readable constructor chain, and neither is checkable by a test the way D-2 is.
- *`json_serializable` per view*: statically typed, and a second transcription of a generated contract. See D-4.
- *`freezed` for unions*: Dart 3 `sealed` classes give exhaustive `switch` natively; `freezed` would add a build step for what the language now does.
- *`dio`*: see D-6.

## Compliance

`.claude/rules/frontend/architecture.md` and
`.claude/rules/frontend/contract-binding.md` carry the enforceable rules.
`app/test/architecture/layering_test.dart` is where D-1, D-2, D-3 and D-9 are
checked; `tool/check_coverage.dart` is where D-11 is.
