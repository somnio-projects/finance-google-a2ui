# CLAUDE.md — client_flutter

Flutter 3.35+ · Dart 3.10+ · a Dart **pub workspace** (`app/`, `e2e_test/`) ·
`genui 0.10.3` · `genui_a2a 0.10.1` · `a2ui_core 0.1.1` (all **alpha**, pinned
exactly) · `flutter_bloc 9.1.1` · `provider` · `logging`. Web-first by mandate;
iOS and Android targets land with GGU-1. Part of the Somnio × Google A2UI
showcase (Jira `GGU`). Read the root [`CLAUDE.md`](../CLAUDE.md) first.

Rules for this folder: **project** rules in [`.claude/rules/client/`](../.claude/rules/client/)
(architecture · presentation · testing · security) sitting on top of the
**generic** Somnio Flutter rules in [`.claude/rules/flutter/`](../.claude/rules/flutter/),
which are synced from `somnio-ai-tools` and are never edited here. Where the
two disagree, the project rules win — `client/architecture.md` opens with the
three places they do.

## The one thing to know before writing a line

**The backend shapes every payload; this client transforms nothing.** It binds
what it receives. It never formats a number, never computes a figure, never
derives a field, never interprets a template, never invents a view id. That is
[ADR-K](../docs/adr/ADR-K-response-shaping.md), it is the point of the
showcase, and the rule that spells out what a reviewer rejects is
[`client/presentation.md`](../.claude/rules/client/presentation.md). If a
widget seems to need a value the payload lacks, the fix is a backend
projection, not a line of Dart.

## Run

```bash
docker compose up --build          # from the repo root: Postgres + backend on :8000
cd client_flutter && flutter pub get                      # resolves the whole workspace
cd client_flutter/app && flutter run -d chrome \
  --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

One `flutter pub get` at `client_flutter/` resolves both workspace members and
writes one lockfile. `BACKEND_BASE_URL` is the only `--dart-define` this client
takes; a `--dart-define` is compiled into the bundle in plaintext, so it may
carry configuration and **never** a secret (`client/security.md` §3).

The client is not part of the compose stack.

## Verify — a change is not done without this

```bash
cd client_flutter && dart format --output=none --set-exit-if-changed .
cd client_flutter && dart analyze --fatal-infos --fatal-warnings
cd client_flutter/app && flutter test --coverage
cd client_flutter/app && flutter build web --release
```

These four are `dart.format`, `dart.analyze`, `flutter.test` and `flutter.web`
in [`.claude/ship-gate.json`](../.claude/ship-gate.json). **They sit under
`_candidates`, not `required`** — the file's own note says *"Flutter gate lands
with GGU-1"*. Two more, `client.tokens` and `client.config`
(`bash tool/check_tokens.sh` / `check_config.sh`, run from `client_flutter/`),
plus `.github/workflows/client-ci.yaml` and the Flutter pre-commit hooks,
arrive with that ticket. Until it merges, a client-only PR can go green without
compiling a line of Dart — so run the four by hand, every time.

Never restate a threshold here that lives in `ship-gate.json`; change one,
change its pair (`.claude/rules/ci-conventions.md` §5).

## Layout and what may import what

```
pubspec.yaml                       the workspace root: `workspace: [app, e2e_test]`
analysis_options.yaml              one analyzer config for both members; strict casts/inference/raw types
app/lib/main.dart                  barrel — `export 'src/main.dart';` and nothing else
app/lib/src/main.dart              composition root: resolves config, builds the theme, runs the app
app/lib/src/config/                AppConfig — every --dart-define is read HERE and nowhere else
app/lib/src/theme/                 ColorScheme + the FinanceTokens ThemeExtension — every colour
app/lib/src/primitives.dart        shared widget primitives; knows no feature
app/lib/src/features/<f>/view/     widgets; may import its bloc, theme, primitives — never a repository
app/lib/src/features/<f>/bloc/     Bloc/Event/State; may import its repository — never flutter/material
app/lib/src/features/<f>/repository/  the only code that speaks to the backend or the genui connector
app/test/                          mirrors app/lib/src path for path
e2e_test/                          out-of-process harness; depends on app/ — app/ never depends on it
```

`view → bloc → repository → transport`, one way, never skipping a layer. The
full table, including what each layer must **not** import, is
[`client/architecture.md`](../.claude/rules/client/architecture.md) §2.

**Where this stands today:** `config/` and `theme/` arrive with GGU-1 (PR #26),
which also renames the app package from the inherited `restaurant_finder_client`
to `finance_a2ui_client` and adds the iOS and Android targets. The layout above
is the contract; two of its folders are one merge away.

## Constraints that are checked, and constraints that are not

Said plainly, because the client's gate is much younger than the backend's.

| Constraint | Checked by |
|---|---|
| Canonical formatting | `dart.format` *(GGU-1)* |
| Strict analysis, zero infos or warnings, no `print` | `dart.analyze` *(GGU-1)* |
| No colour literal outside `theme/` | `client.tokens` *(GGU-1)* |
| No endpoint URL outside `config/` | `client.config` *(GGU-1)* |
| Suite passes; release web bundle compiles | `flutter.test`, `flutter.web` *(GGU-1)* |
| **220-line Dart file budget** | **nothing — review only** |
| **Layer import direction** | **nothing — review only** |
| **Bind-don't-transform (ADR-K)** | **nothing — review only**, except the verbatim-binding widget test |
| **≥ 80 % line coverage per file** | **nothing** — `--coverage` runs and uploads `lcov.info`; no threshold is asserted |

**The file budget is 220 lines** for every `.dart` under `*/lib/`, not the
backend's 150, and the reasoning is written into
[`client/architecture.md`](../.claude/rules/client/architecture.md) §4 rather
than asserted here: Dart under this analyzer puts one widget argument per line,
every file carries a 14-line licence header, and the number was calibrated
against the twelve files actually in the tree (median 65, one file at 247 that
genuinely does three jobs). Over budget → split by responsibility; a
`_buildSection` helper on the same class is not a split.

## Tests

- `app/test/**` mirrors `app/lib/src/**`. Unit tests for pure Dart, widget tests for trees, bloc tests for state sequences.
- **Every widget that renders a backend value gets a verbatim-binding test**: assert `find.text(fake.marketValueDisplay)`, never `find.text(r'$1,234.56')`. The literal version passes whether the widget bound the value or formatted it; the other goes red the moment someone formats. It is the only automated defence ADR-K has on this side.
- **Mutation-check the wiring**: delete the line, confirm red, restore, say so in the PR. Required for the `Authorization` header write, `X-A2A-Extensions` (its failure is *silent* — A2UI degrades to a text agent), `BlocProvider` registration, the `ThemeExtension` registration and the `AppConfig` resolution.
- Prefer fakes to mocks. `bloc_test`, `mocktail` and `checks` are **not** dependencies today — `app/pubspec.yaml` declares only `flutter_test` — so bloc tests are hand-written against the stream. That manifest is GGU-1's file; coordinate, do not edit it in parallel.
- `e2e_test/` needs a live backend and a Gemini key. It does not run in CI and is not expected to; a PR that could not run it says so under `Test decision:`.

Details: [`client/testing.md`](../.claude/rules/client/testing.md).

## Adding a feature

1. Write `specs/client/NNNN-<feature>.md` from [`specs/TEMPLATE.md`](../specs/TEMPLATE.md) — problem, scope, the **contract it consumes** (which view ids, which endpoints), acceptance criteria, test plan, security notes. A human approves it before code. Baseline: [`specs/client/0001-client-foundation.md`](../specs/client/0001-client-foundation.md).
2. **Check the backend can already answer it**: `GET /v1/views` lists every projection with its options schema and a real example. If the shape you need is not there, the work starts in `backend/src/app/presentation/views/` — not in Dart.
3. Build the slice outward: `repository/` → `bloc/` → `view/`, each with its tests.
4. Run the four verify commands, update the diagram if the structure moved (`.claude/rules/diagrams.md`), open the PR into `develop` with `Spec:` and `Test decision:` lines, then append to `.claude/harness-log.md`.

## Security posture

Governed by [ADR-B](../docs/adr/ADR-B-auth-credential-contract.md); the rules
are [`client/security.md`](../.claude/rules/client/security.md). In short:

Firebase **ID token** only, as `Authorization: Bearer`, with `X-A2A-Extensions`
preserved beside it; the **refresh token never reaches our backend**; the token
lives only in the connector's mutable header map and is never persisted;
force-refresh plus **one** retry on `auth/expired-token`, and any other 401/403
signs the user out. Only `/.well-known/agent-card.json` and `/health` are
unauthenticated. No secret in a `--dart-define`, no credential file in the
tree, no token or PII in logs, HTTPS outside loopback. **There is no deep-link
surface** — ADR-I keeps `Navigator` and registers no URL scheme, so no
untrusted input reaches the app through a link; adding one amends that ADR.

The control mapping, `client_flutter/docs/SECURITY.md`, is **(planned)** —
GGU-82's `feat(client)` PR. Until it exists, `client/security.md` is the whole
of the written posture.

## Do not touch

- `.env`, `.env.*`, `google-services.json`, `GoogleService-Info.plist`, keystores, provisioning profiles — denied by permissions and by [ADR-B](../docs/adr/ADR-B-auth-credential-contract.md) D-10.
- [`.claude/rules/flutter/`](../.claude/rules/flutter/) — synced from `somnio-ai-tools`. Project rules go in `.claude/rules/client/`.
- `.claude/ship-gate.json`, `.github/workflows/client-ci.yaml`, `.pre-commit-config.yaml` — the client gate is GGU-1's (PR #30). A rule that needs a new check cites it by name and says it lands with that ticket.
- `client_flutter/app/{lib,test,android,ios}/**` and `app/pubspec.yaml` while GGU-1 (PR #26) is open.
- The pinned alpha versions (`genui`, `genui_a2a`, `a2ui_core`) and the Flutter SDK pin in `.fvmrc` — they are recorded in [ADR-D](../docs/adr/ADR-D-a2ui-streaming-transport.md) D-4, and `.fvmrc` must move together with `FLUTTER_VERSION` in `client-ci.yaml`.
