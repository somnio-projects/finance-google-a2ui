# CLAUDE.md — frontend

Flutter 3.47.5 · Dart 3.13.4 · Bloc · go_router · Material 3. A **pub
workspace**: one lockfile, one analyzer configuration, five packages. This is
the A2UI client — it binds backend-shaped payloads to catalog components and
transforms nothing. Read the root `CLAUDE.md` first; the decisions behind this
layout are [ADR-L](../docs/adr/ADR-L-client-architecture.md) and the spec is
[`specs/frontend/0001-frontend-skeleton.md`](../specs/frontend/0001-frontend-skeleton.md).

> Not to be confused with `client_flutter/`, a separate, older app owned by
> another developer. The two share no code and no pipeline. Do not edit it from
> here.

## Run

### The SDK is pinned, and the pin is a file

Flutter **3.47.5**, which vendors Dart **3.13.4**. The version lives in
[`.fvmrc`](.fvmrc) and **nowhere else** — `tool/check_toolchain.sh` reads it on
a laptop and every `Set up the pinned Flutter SDK` step in
`.github/workflows/frontend-ci.yaml` reads it on a runner. It used to *also* be
a `FLUTTER_VERSION` env var in that workflow, where no local command could
reach it, so the pin existed and the gate a developer actually ran was free to
disagree with it (GGU-94). `scripts/check_gate_pairs.sh` now fails if
`FLUTTER_VERSION` reappears in a workflow, or if a second tracked file starts
naming a Flutter version.

Installing it, from a clone with no Flutter. With fvm, if you already use it:

```bash
cd frontend && fvm install && fvm use "$(jq -r .flutter .fvmrc)"
```

Without it — nothing in this gate shells out to fvm:

```bash
v="$(jq -r .flutter frontend/.fvmrc)"
git clone --depth 1 --branch "$v" https://github.com/flutter/flutter.git "$HOME/flutter-$v"
export PATH="$HOME/flutter-$v/bin:$PATH"   # put this in your shell profile
cd frontend && bash tool/check_toolchain.sh
```

That `PATH` line matters more than it looks: `dart` must resolve to the SDK
**Flutter vendors**, not to a Homebrew or system copy. `dart format` does not
read the `sdk: ^3.13.0` constraint in `pubspec.yaml`, so a Homebrew `dart-sdk
3.12.1` — below the declared floor — formats tracked files differently and
exits 65, which reads as a red branch and is a red toolchain. Measured on
`develop` at `c6dd5b2`: 3 files changed / exit 65 under 3.12.1, 0 changed /
exit 0 under the pin.

**`.fvmrc` and not a new `.flutter-version`**, because `.fvmrc` was already
tracked and already cited as the pin by `README.md` and `docs/DEV_HARNESS.md`.
The first attempt at this fix added a second pin file beside it — two
machine-readable pins free to drift, which is the defect GGU-94 exists to
remove, recreated one file over. It took two reviewers to see it, which is why
`check_gate_pairs.sh` now asserts the single home rather than a sentence here
doing so. Nothing requires fvm; the file is read as plain JSON.

```bash
cd frontend && flutter pub get --enforce-lockfile      # once per clone
cd frontend/app && flutter run -d chrome \
  --dart-define=BACKEND_BASE_URL=http://localhost:8000 \
  --dart-define=BACKEND_DEV_TOKEN="$(cd ../../backend && make token SUBJECT=alice)"
```

The backend comes from `docker compose up --build` at the repository root.
`BACKEND_DEV_TOKEN` is a **local-development affordance and a recorded gap**
(`SECURITY.md` G-1): a `--dart-define` is compiled into the bundle, so it never
carries a credential for a deployed environment.

## Verify — a change is not done without this

```bash
cd frontend && make gate    # toolchain · toolchain-test · format · analyze · budget · manifest · tests · coverage
cd frontend && make format  # apply formatting
cd frontend && make manifest # regenerate the component manifest after adding one
cd frontend/app && flutter test --update-goldens   # after an intended visual change
```

`make gate` == the `quality` and `tests` jobs of
`.github/workflows/frontend-ci.yaml` == the `frontend.*` entries in
`.claude/ship-gate.json`, **command string for command string**. Red gate =
not done. Thresholds go up, never down, and never in a feature PR.

CI additionally runs `flutter build web --release`, which the local gate does
**not** — it is slow, and it belongs on a runner for the same reason the
backend's image build does. It is not decoration: it is the job that caught
this app shipping without a `web/` scaffold at all. Run it yourself before a
PR that touches `app/`:

```bash
cd frontend/app && flutter build web --release
```

Always `flutter pub get --enforce-lockfile`. Plain `pub get` silently
re-resolves and builds something nobody reviewed.

## Layout, and what each layer may import

```
frontend/
├── packages/                     pure Dart — cannot import Flutter, by compilation
│   ├── finance_core/             Result, AppFailure, ProblemDetails. Depends on nothing.
│   ├── finance_api_client/       DATA layer: the only code that speaks HTTP.
│   ├── finance_views_repository/ REPOSITORY layer: envelope, ViewPayload, ETag cache.
│   └── finance_charts/           CHART GEOMETRY: scales, nice ticks, (steps, size) → rects.
├── app/lib/                      Flutter
│   ├── bootstrap.dart            THE composition root — the only file that constructs anything
│   ├── main.dart                 runApp(bootstrap())
│   ├── app/                      AppConfig (the only reader of --dart-define), FinanceApp
│   ├── router/                   go_router table + the single auth-gate redirect
│   ├── theme/                    Material 3 themes + the AppSpacing ThemeExtension
│   ├── charts/                   the CustomPainter + ChartPalette — the half that needs dart:ui
│   ├── components/               one directory per catalog view + the generated manifest
│   └── features/<name>/bloc|view business logic and screens
├── test/tool/                    the suite over the gate's own scripts (`make test-tool`)
└── tool/                         the gate's own scripts
```

Dependencies point one way: `view → bloc → repository → api client → core`.

## Rules that are checked, not suggested

- **150 lines per file** (`tool/check_file_budget.dart`), sources *and* tests. Over budget → split by responsibility, never "part 1 / part 2".
- **Layering** (`app/test/architecture/layering_test.dart`, the counterpart of the backend's `test_package_boundaries.py`): no Flutter under `packages/`; blocs never import the api client or `http`; components never import a feature; **only `bootstrap.dart` constructs** an `http.Client`, a `FinanceApiClient` or a `ViewsRepository`; **only a `*_page.dart` reads a repository from the tree** (the page/view split — a page builds its bloc, a `_View` reads state).
- **The numbers rule, as a test** (`app/test/architecture/binding_rules_test.dart`). Twelve number mechanisms — including **both** `double.parse` and `double.tryParse`, and the same for `num` and `int` — plus three clock reads and four interpreter mechanisms are absent from `lib/`, and the test fails on any of them. **One file is allow-listed**, by path: `finance_views_repository/lib/src/raw_decimal.dart`, which turns the contract's raw `amount` into a canvas coordinate for a chart and nothing else (ADR-L D-14). It is not exported from the package barrel, so `ViewPayload.geometry` is its only caller, and `::the geometry seam is the only exemption` asserts the allow set has exactly one member. Payload paths must be string literals, never variables. Every figure on screen is a `*Display` string the backend formatted. If you need one the payload does not carry, **the payload is missing a field — raise it** (spec `client/0003` N-3).
- **Documentation on every public symbol** — `public_member_api_docs` from `very_good_analysis`, made fatal by `dart analyze --fatal-infos`. This is the analyzer doing what `interrogate` does for the backend.
- **100 % line coverage per file, and no `lib/` file without a record** (`tool/check_coverage.dart`). Dart's lcov carries no branch data, so the backend's 100 % *branch* contract cannot be reproduced literally; per-file 100 % line is the honest equivalent and is strictly above the `≥80 %` floor in `.claude/rules/flutter/testing.md`. The script also cross-checks the records against the files on disk, because lcov writes **nothing** for a library no test imports — without that, the rule would have meant "100 % of the files the tests happened to load" and a new untested file would have passed silently. Exemptions are listed in that script with a reason each.
- **The component manifest is generated and gated.** `app/lib/components/component_manifest.g.dart` is re-rendered by the gate and diffed, exactly like the backend's frozen catalog.

## Drawing a chart

`packages/finance_charts` is the geometry — `LinearScale`, `BandScale`,
readable tick steps, `WaterfallLayout.of(steps, width, height)` — and it is
pure Dart, so it runs under `dart test` and its output is **asserted
arithmetically**. `app/lib/charts/` holds the `CustomPainter` and the
`ChartPalette` theme extension, because a painter needs `dart:ui` and
`packages/` may not have it.

No charting library, deliberately: `fl_chart` and `graphic` both format their
own axis labels, which breaks the one product invariant this showcase exists
to demonstrate. The reasoning is ADR-L D-13; the chart's measured design values
are in `app/lib/charts/chart_tokens.dart`.

**Colour literals live in a `*_tokens.dart` and nowhere else.** `AppTheme`
names the seed; each design-bound surface names its own measured palette —
`charts/chart_tokens.dart`, `components/taxlots_table/taxlot_tokens.dart` —
and every other file reads it through a palette object. A component's palette
stays in the component's directory on purpose: registering a `ThemeExtension`
would mean editing `AppTheme` to add one, which ADR-L D-3 forbids. Where two
palettes share a semantic role, a test pins them to each other
(`taxlot_tokens_test.dart::agrees with the chart palette on every shared
role`) so they cannot drift while staying separate.

Responsive through `LayoutBuilder` alone — the painter takes the `Size` and
the scales recompute. There is no breakpoint to keep in step with a design.

## Adding a component — the whole procedure

1. `mkdir app/lib/components/<name>` and write `<name>_component.dart`: a `ViewComponent` subclass with the frozen `viewId`, plus `void register(ComponentRegistry)` at the bottom.
2. Add its widget file(s) beside it and its tests under `app/test/components/<name>/`.
3. `make manifest`, and commit the regenerated file.

**No hand-written file is edited** — no registry list, no enum, no union, no
`if/elif` (ADR-L D-3, mirroring ADR-K D-15). If adding one makes you edit
something, the seam is wrong; fix the seam.

> **This claim was false in two places until GGU-79, and both are now closed.**
> The registration half was always sound — nothing forces an edit to register a
> component. What did not hold was everything *after* registration:
>
> 1. **The component could not reach a screen.** `app/lib/router/app_router.dart`
>    carried a hardcoded `views: ['holdings.allocation.v1']`, and no test
>    compared the router with the registry — so a component could be added,
>    registered, 100 %-covered and **invisible, with a green gate**. The route
>    no longer names any view: `PortfolioViewsPage` asks the registry, so the
>    two cannot disagree. Asserted by
>    `app_router_test.dart::every registered component is reachable from the route`.
> 2. **The fifth component broke the screen.** The read endpoint takes at most
>    `ViewsRepository.maxViewsPerRequest` (4) ids, so a fifth registration made
>    one request exceed the cap and fail the whole surface. The repository now
>    splits the request (`fetchAllPortfolioViews`) and merges the envelopes —
>    every id is still requested, in order, so N-10 is untouched.
>
> The lesson worth keeping: *"adding one edits no existing file"* is a claim
> about the **whole path to the screen**, not about the registry alone. When
> you extend the seam, walk it end to end before repeating the sentence.

## Conventions the code does not show

- **Failure is a value.** Boundaries return `Result<T>`; `AppFailure` is sealed, so a `switch` is exhaustive and a new failure kind is a compile error in every incomplete handler. Nothing throws across a layer.
- **No generated DTOs, deliberately.** A payload is read through `ViewPayload` by dotted path. The source of truth for a payload's shape is the backend's generated `docs/catalog/view-catalog.snapshot.json`; a hand-or-tool-written Dart mirror would be a second source, and the second source is the one that goes stale. See ADR-L D-4 — this is a **recorded deviation** from `.claude/rules/flutter/code-patterns.md`.
- **`go_router`, not `Navigator`** — a recorded deviation from ADR-I, which is scoped to `client_flutter/`. ADR-I D-4 asked that re-adopting it be an amendment rather than a rediscovery; ADR-L D-5 is that amendment.
- **Config in one place.** `AppConfig` is the only reader of `String.fromEnvironment`; nothing else reaches for an ambient value.
- **A 304 is a success.** The repository resolves it to the cached envelope; it is never an error and never an empty result.

## Do not touch

- `pubspec.lock` by hand — change a `pubspec.yaml` and re-resolve.
- `app/lib/components/component_manifest.g.dart` — generated; run `make manifest`.
- `../.claude/rules/flutter/` — synced from `somnio-ai-tools`. This app's own rules are in `../.claude/rules/frontend/`.
- The coverage threshold, the 150-line budget and the `very_good_analysis` rule set — team decisions, not fixes.
