# ADR-L — The `frontend/` client architecture

- **Status:** **Proposed** — awaiting TL ratification. Amended by GGU-55 (D-13, D-14, D-15).
- **Gates:** GGU-91 and every later `frontend/` ticket; the charting rulings gate GGU-55/57/59/61/63/65
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
- **D-12 — The SDK is pinned where a laptop can read it, and the lockfile is enforced.** `pubspec.yaml` floors at Dart `^3.13.0`, `frontend/.fvmrc` pins Flutter `3.47.5`, and every install is `flutter pub get --enforce-lockfile`. Plain `pub get` silently re-resolves; the strict flag fails instead of quietly changing the dependency graph.

  *Amended 2026-09-21 (GGU-94).* This ruling used to say the pin lived in `frontend-ci.yaml`, and that was the defect: `dart format` does not consult `pubspec.yaml`'s SDK constraint, so a laptop with a Dart *below* the declared floor ran the gate happily and reported three correctly-formatted files as unformatted — a red gate that reads as a red branch. **A version pinned where only CI can read it is not a pin; it is a claim CI happens to satisfy.** The pin moved to `.fvmrc`, which was already tracked and already cited as the pin by `frontend/README.md`; `frontend/tool/check_toolchain.sh` reads it as the gate's first step and `frontend-ci.yaml` reads it to install the SDK. `scripts/check_gate_pairs.sh` fails if a workflow declares `FLUTTER_VERSION` again or if a second pin file appears — the first attempt at this fix added one.

- **D-13 — Charts are a small package of primitives over `CustomPainter`, not a charting library.** `fl_chart` and `graphic` were both proposed and both are rejected. Three reasons, in order of weight:
  - **A chart library formats numbers.** `fl_chart`, `graphic` and Syncfusion all generate their own axis and tooltip labels by formatting the values they are given. That is prohibition N-1 (ADR-E, ADR-K D-5) broken silently, inside a dependency, on the one product invariant this showcase exists to demonstrate: *the LLM never computes a financial figure, and neither does the client*. A library that ships its own `NumberFormat` cannot be made to obey a rule the repository enforces by grepping for `NumberFormat`.
  - **The design is bespoke and measured.** GGU-42 specifies bar widths that cap, connectors that leave a bar at its running total, value labels that disappear when their band narrows, and a two-interval nice-ed axis. Pixel-perfection against a design is exactly where an opinionated chart library stops helping and starts being worked around.
  - **The agent supplies declared props, not a config DSL.** A component renders from a payload the backend shaped (ADR-K). A library with its own configuration language inserts a second translation between what the agent declared and what is drawn — a place for the two to disagree that no test can see.
  What is actually worth having from d3 is not its renderer but its arithmetic: `scaleLinear`, `scaleBand`, tick selection, and layout functions. `packages/finance_charts` ports that, in ~350 lines of pure Dart, and `app/lib/charts/` holds the painter.
  - *The split is forced, and it is a gift.* `packages/` may not import `dart:ui` (D-1), so the painter cannot live there. What is left in the package is *(steps, size) → rectangles and points* — a pure function, run under `dart test` in a second, whose output is asserted **arithmetically**: seven bar tops and seven heights compared against the designer's rendered DOM to 0.1 px. A golden tells you something moved; the geometry tells you what. Both are kept, and the GGU-55 mutation check changes one scale's target interval count and watches three geometry tests — fourteen assertions, seven bar tops and seven heights — **and** all three goldens go red together.
  - *Accepted cost:* legends, zoom, animation and accessibility affordances a mature library ships are ours to write. The bet is that six bespoke components need less of that than they need to match a design and never format a number. Revisit if a chart needs real interaction beyond a tap.
- **D-14 — One path-scoped exemption to the numbers rule: `rawDecimal`, for geometry.** D-9 says `double.parse` is absent from `lib/`, and until GGU-55 that was costless because nothing drew a chart. It is not costless now. The contract keeps a raw `amount` beside every `*Display` string **precisely so a chart can be drawn from it** (spec `client/0003` N-4: "`amount`, `value` and `units` exist for chart geometry"), and the value-to-pixel mapping cannot move to the server, which does not know the width the client will be laid out in. `packages/finance_views_repository/lib/src/raw_decimal.dart` is therefore allowed `double.tryParse` and is the **only** file that is — the same shape as `jsonDecode` in the transport, and allow-listed by name in `binding_rules_test.dart`. `ViewPayload.geometry(path)` is its one caller.
  - *What keeps it narrow:* the allowance is per **file**, the file is five lines, and it is **not exported from the package barrel** — `ViewPayload.geometry(path)` is its only caller, so nothing above the repository layer can reach it. `binding_rules_test.dart::the geometry seam is the only exemption` asserts the allow set has exactly one member and that it still names a file that exists; the rule itself was mutation-checked by moving `double.tryParse` into `view_payload.dart` and watching it fail. The result is a position on a canvas: it never reaches a `Text`, is never re-formatted, and never becomes a figure a human reads.
  - *This supersedes the sentence in `.claude/rules/frontend/contract-binding.md` that said `ViewPayload` exposes no numeric accessor and one must not be added back.* That sentence was right about a `json` getter, which would have exposed the whole payload with nothing stopping arithmetic on it; it was too broad about a named, single-purpose reader. The rule file now carries both halves.
- **D-15 — Goldens compare with a small tolerance, because a raster is not portable.** Flutter's default comparator demands a byte-identical PNG, and the same widget anti-aliases a rounded corner differently on a laptop and on the Linux runner `frontend-ci` uses. A byte-exact golden generated on macOS is a check that fails on CI for a reason that is not a defect — and the fix everyone reaches for is to stop running it. `app/test/flutter_test_config.dart` installs a comparator allowing **1.5 %** of pixels to differ — 2.2× the *measured* cross-platform noise floor of 0.69 %, and 3.3× below the smallest defect worth catching.
  - *Both ends of that are measurements, which is the difference between setting a threshold and fitting one.* The first guess was 0.5 %, CI rejected it at 0.69 %, and the response was to measure both ends rather than nudge the number until the run went green. The threshold goes **down** as the noise is understood better, never up to absorb a failure.
  - *The margin.* A defect worth catching moves 5–7 % of the image (the value scale's domain wrong: 6.9 %; one bar in the wrong mark: 5.0 %). The **first attempt goldened the whole card and had to be redone**: glyph edges are where nearly all cross-platform difference lives, and whole-card goldens drifted 0.54–0.70 % between macOS and the Linux runner against a smallest-defect signal of 1.26 % — a signal-to-noise ratio under two, which is not a gate anybody should trust. Widening the tolerance to fit that would have been threshold-fitting; goldening the **chart** instead removed the noise at its source. The card's text is asserted by `find.text`, which is a better check for text than a raster, and its chrome by its constants.
  - *The stated limit:* a bar's corner radius changing 4 px → 3 px moves 0.08 %, below what a cross-platform raster resolves. That constant is asserted directly rather than left to a golden. The exact geometry is proved arithmetically in `finance_charts`, which is what makes a tolerance here safe rather than a loosened threshold.

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

**Closed — the contract is no longer bound to a fixture.** `frontend/0001`
OD-1 recorded that component tests bound a *copy* of a rendered example while
`docs/catalog/view-catalog.snapshot.json` did not exist on `develop`. It does
now (GGU-53), and `app/test/helpers/catalog_snapshot.dart` reads it:
`attribution_waterfall_component_test.dart` binds the generated example
directly, and `app/test/architecture/catalog_contract_test.dart` asserts that
every registered component's view id and A2UI component name are ones the
backend actually publishes. A rename on the backend — four of six happened in
one commit during GGU-53 — is now a red client suite rather than a placeholder
on screen.

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
