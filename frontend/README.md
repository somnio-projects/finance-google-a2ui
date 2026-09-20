# frontend — the A2UI finance client

A Flutter web-first client for the Somnio × Google A2UI showcase. The backend
shapes every payload; this app **binds what it receives** and transforms
nothing — no formatting, no arithmetic, no re-ordering
([ADR-K](../docs/adr/ADR-K-response-shaping.md)).

> A second Flutter app, `client_flutter/`, also lives in this repository. The
> two share no code, no pipeline and no specs. This one is GGU-91.

## Quick start

```bash
cd frontend
flutter pub get --enforce-lockfile        # never plain `pub get` — it re-resolves silently

# in another shell, from the repository root:
docker compose up --build                 # Postgres + backend on :8000

cd app && flutter run -d chrome \
  --dart-define=BACKEND_BASE_URL=http://localhost:8000 \
  --dart-define=BACKEND_DEV_TOKEN=<a token from `cd backend && make token`>
```

`BACKEND_DEV_TOKEN` is for local development only and is a recorded gap
([`SECURITY.md`](SECURITY.md) G-1): a `--dart-define` is compiled into the
bundle, so it must never carry a credential for a deployed environment.

## Verify

```bash
make gate     # format · analyze · 150-line budget · component manifest · tests · coverage
```

One command, red means not done. It is character-identical to
`.github/workflows/frontend-ci.yaml` and to the `frontend.*` entries in
`../.claude/ship-gate.json`.

## Layout

| Path | Layer | May import |
|---|---|---|
| `packages/finance_core` | kernel | nothing but `equatable` |
| `packages/finance_api_client` | data — the only HTTP speaker | core, `http` |
| `packages/finance_views_repository` | repository | core, api client |
| `app/` | Bloc + widgets | all three, Flutter |

The three packages are **pure Dart**, so importing Flutter into them is a
compile error rather than a convention. `app/test/architecture/layering_test.dart`
holds the rest of the import graph, the single composition root, and the rule
that no figure is ever formatted or computed on the client.

## Toolchain

Flutter **3.47.5** / Dart **3.13.4**, pinned in `.fvmrc` and in the CI
workflow. One `pubspec.lock` for the whole workspace, enforced on every
install.

## Where the decisions live

| Question | Document |
|---|---|
| Why four packages, why `go_router`, why no generated DTOs | [ADR-L](../docs/adr/ADR-L-client-architecture.md) |
| What this PR delivered and what it deliberately left out | [`specs/frontend/0001-frontend-skeleton.md`](../specs/frontend/0001-frontend-skeleton.md) |
| The payload contract and its fifteen prohibitions | [`specs/client/0003-client-backend-contract.md`](../specs/client/0003-client-backend-contract.md) |
| Controls, and the gaps that are **not** controls | [`SECURITY.md`](SECURITY.md) |
| Day-to-day rules for changing this code | [`CLAUDE.md`](CLAUDE.md), `../.claude/rules/frontend/` |
| The import graph, as a picture | [`docs/diagrams/12-frontend-layers.md`](../docs/diagrams/12-frontend-layers.md) |

## Adding a component

Create `app/lib/components/<name>/<name>_component.dart` with a
`ViewComponent` and one `register(ComponentRegistry)`, add its tests, then run
`make manifest`. **No existing file is edited** — the wiring lives in a
generated manifest the gate re-renders and diffs.
