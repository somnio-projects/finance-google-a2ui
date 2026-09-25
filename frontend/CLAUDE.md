# CLAUDE.md — frontend

Flutter 3.47.5 · Dart 3.13.4 · Bloc · go_router · Material 3. A **pub
workspace**: one lockfile, one analyzer configuration, five packages. This is
the A2UI client — it binds backend-shaped payloads to catalog components and
transforms nothing. Read the root `CLAUDE.md` first; the decisions behind this
layout are [ADR-L](../docs/adr/ADR-L-client-architecture.md) and the spec is
[`specs/frontend/0001-frontend-skeleton.md`](../specs/frontend/0001-frontend-skeleton.md).

> This is the **only** Flutter app in the repository. A second one,
> `client_flutter/`, existed until 2026-09-22 and was retired in full (spec
> [`repo/0002`](../specs/repo/0002-retire-the-client-flutter-app.md)). It
> shared no code with this one; references to it below are history, kept
> because they are the reasons some of these decisions look the way they do.

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
cd frontend && make gate    # toolchain · toolchain-test · verify-release-test · format · analyze · budget · manifest · tests · coverage
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

## It runs in the stack, and it ships itself

```bash
# from the repository root — no Flutter SDK needed
APP_RELEASE="local+$(git rev-parse --short HEAD)" docker compose up --build
```

`:3001`, in the one compose project `finance-a2ui`, as part of the default
`up`. `docker compose up db backend` skips its build. Delivery is
`.github/workflows/frontend-cd.yaml`, a button: gate → bundle → preview
channel → verify → live → verify. Spec
[`frontend/0017`](../specs/frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md),
drawn in [diagram 13](../docs/diagrams/13-client-delivery.md).

Three things about it are easy to get wrong and are enforced:

- **The build flags live in `tool/build_web.sh` and nowhere else.** The
  Dockerfile and the workflow both call it. Neither is a ship-gate command, so
  `repo.gate-pairs` cannot compare them — this is the one pair with no machine
  check, and the defence is not writing the list twice.
- **The image's Flutter version comes from `.fvmrc`**, resolved to a checksum
  through `docker/flutter-sdk-checksums.json`. `scripts/check_gate_pairs.sh`
  rule 3 fails a Dockerfile that names a version, or one that does not `COPY`
  the pin in. It exists because `client_flutter/Dockerfile` had drifted exactly
  that way (spec 0017 OD-7) — that app is gone, the rule is not, and this
  Dockerfile is what it holds today.
- **Configuration is compiled in, so the image is per environment** — the
  opposite of what `client_flutter` decided (its Dockerfile's Decision 1),
  because this app's deployable is a static Hosting release with no process to
  render `/config.json`. What
  replaces artifact identity is verification after the fact: `/release.json`,
  read back off the origin by the pipeline that published it.

## Layout, and what each layer may import

```
frontend/
├── packages/                     pure Dart — cannot import Flutter, by compilation
│   ├── finance_core/             Result, AppFailure, ProblemDetails. Depends on nothing.
│   ├── finance_api_client/       DATA layer: the only code that speaks HTTP.
│   ├── finance_views_repository/ REPOSITORY layer: envelope, ViewPayload, ETag cache.
│   ├── finance_auth/             AUTH: session, IdentityProvider seam, AccessGateway, AuthRepository.
│   └── finance_charts/           CHART GEOMETRY: scales, nice ticks, (steps, size) → rects.
├── app/lib/                      Flutter
│   ├── bootstrap.dart            THE composition root — the only file that constructs anything
│   ├── main.dart                 initialises Firebase when configured, then runApp(bootstrap(...))
│   ├── auth/                     the Firebase IdentityProvider and the router's AuthGate — the only Firebase importers
│   ├── app/                      AppConfig (the only reader of --dart-define), FinanceApp
│   ├── router/                   go_router table + the single auth-gate redirect
│   ├── theme/                    Material 3 themes + the AppSpacing ThemeExtension
│   ├── charts/                   the CustomPainter + ChartPalette — the half that needs dart:ui
│   ├── components/               one directory per catalog view + the generated manifest
│   ├── speech/                   the dictation seam — speech_web.dart is the ONLY file
│   │                             allowed dart:js_interop / package:web, and the only
│   │                             coverage exemption after main.dart (spec frontend/0023)
│   └── features/<name>/bloc|view business logic and screens
├── docker/                       nginx config + entrypoint for the container (CSP, COOP)
├── Dockerfile                    builder (SDK read from .fvmrc) + nginx-unprivileged runtime
├── test/tool/                    the suite over the gate's own scripts (`make test-tool`)
└── tool/                         the gate's own scripts, and the two delivery ones:
                                  build_web.sh (the ONE home of the build flags,
                                  called by Dockerfile and frontend-cd) and
                                  verify_release.sh (asks a deployed origin
                                  which build it serves)
```

Dependencies point one way: `view → bloc → repository → api client → core`.

## Rules that are checked, not suggested

- **150 lines per file** (`tool/check_file_budget.dart`), sources *and* tests. Over budget → split by responsibility, never "part 1 / part 2".
- **Layering** (`app/test/architecture/layering_test.dart`, the counterpart of the backend's `test_package_boundaries.py`): no Flutter under `packages/`; blocs never import the api client or `http`; components never import a feature; **only `bootstrap.dart` constructs** an `http.Client`, a `FinanceApiClient` or a `ViewsRepository`; **only a `*_page.dart` reads a repository from the tree** (the page/view split — a page builds its bloc, a `_View` reads state).
- **The numbers rule, as a test** (`app/test/architecture/binding_rules_test.dart`). Twelve number mechanisms — including **both** `double.parse` and `double.tryParse`, and the same for `num` and `int` — plus three clock reads and four interpreter mechanisms are absent from `lib/`, and the test fails on any of them. **One file is allow-listed**, by path: `finance_views_repository/lib/src/raw_decimal.dart`, which turns the contract's raw `amount` into a canvas coordinate for a chart and nothing else (ADR-L D-14). It is not exported from the package barrel, so `ViewPayload.geometry` is its only caller, and `::the geometry seam is the only exemption` asserts the allow set has exactly one member. Payload paths must be string literals, never variables. Every figure on screen is a `*Display` string the backend formatted. If you need one the payload does not carry, **the payload is missing a field — raise it** (spec `client/0003` N-3).
- **Documentation on every public symbol** — `public_member_api_docs` from `very_good_analysis`, made fatal by `dart analyze --fatal-infos`. This is the analyzer doing what `interrogate` does for the backend.
- **The browser is behind a seam.** `app/lib/speech/` holds the `SpeechRecognizer` interface; `speech_web.dart` is the only file that may import `dart:js_interop` or `package:web`, and `bootstrap.dart` — through a conditional import — is the only file that names either implementation. `app/test/architecture/speech_rules_test.dart` fails on the mechanism, and the allowance's *size* is asserted, like the geometry seam's. A platform API a test cannot start belongs behind an interface a test can fake (spec `frontend/0023`).
- **100 % line coverage per file, and no `lib/` file without a record** (`tool/check_coverage.dart`). Dart's lcov carries no branch data, so the backend's 100 % *branch* contract cannot be reproduced literally; per-file 100 % line is the honest equivalent and is strictly above the `≥80 %` floor in `.claude/rules/flutter/testing.md`. The script also cross-checks the records against the files on disk, because lcov writes **nothing** for a library no test imports — without that, the rule would have meant "100 % of the files the tests happened to load" and a new untested file would have passed silently. Exemptions are listed in that script with a reason each; there are **two** — `lib/main.dart` and `lib/speech/speech_web.dart`, both boundaries to something a test cannot start, never merely hard-to-test code.
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

**Colour literals live in a `*_tokens.dart` or a `*_palettes.dart`, and
nowhere else — and that is now a test, not a sentence**
(`app/test/architecture/color_rules_test.dart`, spec `frontend/0029` OD-4).
`AppTheme` names the seed; each design-bound surface names its own measured
palette — `charts/chart_tokens.dart`,
`components/taxlots_table/taxlot_tokens.dart` — and every other file reads it
through a palette object. A component's palette stays in the component's
directory on purpose: registering a `ThemeExtension` would mean editing
`AppTheme` to add one, which ADR-L D-3 forbids. Where two palettes share a
semantic role, a test pins them to each other
(`taxlot_tokens_test.dart::agrees with the chart palette on every shared
role`) so they cannot drift while staying separate.

The rule is a **naming convention** rather than a list of allowed paths, for
that same reason: a path list would have to be edited every time a component is
added, so the check would be the seam violation it protects. The exception set
is empty and the test asserts it. Four files used to claim *"this is the only
file in `app/lib/` naming a `Color`"* and all four sentences were false when
GGU-105 read them — twenty-one files named one, five of them widgets. A value
that is the same on both artboards is a `static const` on the token class
(`LoginTokens.logoGradient`, `HoldingsTokens.toggleShadow`), not a
`ThemeExtension` field. `Colors.white` is **not** covered: nine occurrences in
four files, left alone on purpose because moving them is a design decision
about dark mode rather than a file-location one (0029 OD-5).

Responsive through `LayoutBuilder` alone — the painter takes the `Size` and
the scales recompute. There is no breakpoint to keep in step with a design.

## Adding a component — the whole procedure

1. `mkdir app/lib/components/<name>` and write `<name>_component.dart`: a `ViewComponent` subclass with the frozen `viewId`, plus `void register(ComponentRegistry)` at the bottom.
2. Add its widget file(s) beside it and its tests under `app/test/components/<name>/`. If its design page draws a loading skeleton, override `skeleton(BuildContext)` in a `<name>_skeleton.dart` there too (spec frontend/0015 OD-3); otherwise the Assistant's generic surface stands in.
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
>    no longer names any view: the page asks the registry (today `CatalogPage`,
>    which crosses it with the backend's catalog — spec frontend/0016), so the
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
