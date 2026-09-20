# CLAUDE.md — frontend

Flutter 3.47.5 · Dart 3.13.4 · Bloc · go_router · Material 3. A **pub
workspace**: one lockfile, one analyzer configuration, four packages. This is
the A2UI client — it binds backend-shaped payloads to catalog components and
transforms nothing. Read the root `CLAUDE.md` first; the decisions behind this
layout are [ADR-L](../docs/adr/ADR-L-client-architecture.md) and the spec is
[`specs/frontend/0001-frontend-skeleton.md`](../specs/frontend/0001-frontend-skeleton.md).

> Not to be confused with `client_flutter/`, a separate, older app owned by
> another developer. The two share no code and no pipeline. Do not edit it from
> here.

## Run

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
cd frontend && make gate    # format · analyze · budget · manifest · tests · coverage
cd frontend && make format  # apply formatting
cd frontend && make manifest # regenerate the component manifest after adding one
```

`make gate` == `.github/workflows/frontend-ci.yaml` == the `frontend.*` entries
in `.claude/ship-gate.json`, **command string for command string**. Red gate =
not done. Thresholds go up, never down, and never in a feature PR.

Always `flutter pub get --enforce-lockfile`. Plain `pub get` silently
re-resolves and builds something nobody reviewed.

## Layout, and what each layer may import

```
frontend/
├── packages/                     pure Dart — cannot import Flutter, by compilation
│   ├── finance_core/             Result, AppFailure, ProblemDetails. Depends on nothing.
│   ├── finance_api_client/       DATA layer: the only code that speaks HTTP.
│   └── finance_views_repository/ REPOSITORY layer: envelope, ViewPayload, ETag cache.
├── app/lib/                      Flutter
│   ├── bootstrap.dart            THE composition root — the only file that constructs anything
│   ├── main.dart                 runApp(bootstrap())
│   ├── app/                      AppConfig (the only reader of --dart-define), FinanceApp
│   ├── router/                   go_router table + the single auth-gate redirect
│   ├── theme/                    Material 3 themes + the AppSpacing ThemeExtension
│   ├── components/               one directory per catalog view + the generated manifest
│   └── features/<name>/bloc|view business logic and screens
└── tool/                         the gate's own scripts
```

Dependencies point one way: `view → bloc → repository → api client → core`.

## Rules that are checked, not suggested

- **150 lines per file** (`tool/check_file_budget.dart`), sources *and* tests. Over budget → split by responsibility, never "part 1 / part 2".
- **Layering** (`app/test/architecture/layering_test.dart`, the counterpart of the backend's `test_package_boundaries.py`): no Flutter under `packages/`; blocs never import the api client or `http`; components never import a feature; **only `bootstrap.dart` constructs** an `http.Client`, a `FinanceApiClient` or a `ViewsRepository`.
- **The numbers rule, as a test.** `NumberFormat`, `package:intl`, `dart:math`, `toStringAsFixed`, `double.parse` and `DateTime.now()` are all absent from `lib/`, and the layering test fails on any of them. Every figure on screen is a `*Display` string the backend formatted. If you need one the payload does not carry, **the payload is missing a field — raise it** (spec `client/0003` N-3).
- **Documentation on every public symbol** — `public_member_api_docs` from `very_good_analysis`, made fatal by `dart analyze --fatal-infos`. This is the analyzer doing what `interrogate` does for the backend.
- **100 % line coverage per file** (`tool/check_coverage.dart`). Dart's lcov carries no branch data, so the backend's 100 % *branch* contract cannot be reproduced literally; per-file 100 % line is the honest equivalent and is strictly above the `≥80 %` floor in `.claude/rules/flutter/testing.md`. Exemptions are listed in that script with a reason each.
- **The component manifest is generated and gated.** `app/lib/components/component_manifest.g.dart` is re-rendered by the gate and diffed, exactly like the backend's frozen catalog.

## Adding a component — the whole procedure

1. `mkdir app/lib/components/<name>` and write `<name>_component.dart`: a `ViewComponent` subclass with the frozen `viewId`, plus `void register(ComponentRegistry)` at the bottom.
2. Add its widget file(s) beside it and its tests under `app/test/components/<name>/`.
3. `make manifest`, and commit the regenerated file.

**No hand-written file is edited** — no registry list, no enum, no union, no
`if/elif` (ADR-L D-3, mirroring ADR-K D-15). If adding one makes you edit
something, the seam is wrong; fix the seam.

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
