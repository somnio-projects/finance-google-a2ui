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
  --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Sign in with **`demo@somnio.dev`** on the e-mail path: the local stack has no
Firebase, so the backend's preview sign-in answers it for a provisioned
e-mail (spec `backend/0027` OD-3; `docker-compose.yml` provisions that one at
boot). To sign in through Firebase — Google or an e-mail link — pass its
**public** web config, which is not a credential (ADR-B D-10):

```bash
  --dart-define=FIREBASE_API_KEY=… --dart-define=FIREBASE_APP_ID=… \
  --dart-define=FIREBASE_PROJECT_ID=finance-a2ui \
  --dart-define=FIREBASE_AUTH_DOMAIN=finance-a2ui.firebaseapp.com \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=…
```

The five values are one file away from a build: copy
`app/config/firebase.example.json` to `app/config/firebase.json` (git-ignored),
paste the web `apiKey` from the Firebase console (*Project settings › Your
apps › Default Web App*; it is the public browser key, ADR-B D-10), and pass
the file — it also carries `BACKEND_BASE_URL`, so one file names one
environment:

```bash
cd app && flutter build web --release --dart-define-from-file=config/firebase.json
firebase deploy --only hosting     # firebase.json serves app/build/web at finance-a2ui.web.app
```

**`--only hosting` is not optional.** The root `firebase.json` also carries an
`auth` block — config-as-code for Authentication — and a bare `firebase deploy`
would replace the project's authorized domains with that list.

## Run it as a container

No Flutter SDK needed. From the repository root:

```bash
APP_RELEASE="local+$(git rev-parse --short HEAD)" docker compose up --build
```

The client is then on **http://localhost:3001**, under the one compose project
`finance-a2ui`, alongside Postgres and the backend — it is part of the default
`up`, not behind a profile. To skip its build, name the other services:
`docker compose up db backend`.

The image is **per environment**, unlike `client_flutter`'s, and the reason is
in `Dockerfile` Decision 1: this app's deployable is a static Hosting release,
which has no process to render a `/config.json` at start. The default build
args are the local stack — the backend on `:8000`, and **no** Firebase, so the
Google button says it is not configured and the e-mail path is the backend's
preview sign-in with `demo@somnio.dev`. To build it against a real environment,
pass the five public values as `--build-arg`.

`GET /release.json` says which build is being served — `local+<sha>` when the
stack was brought up with `APP_RELEASE`, exactly as the backend's `/health`
does. It is the same file the delivery pipeline reads back off a deployed
origin.

## Deliver it

Actions → **frontend-cd** → *Run workflow*, on `develop` (dev) or `main`
(production, behind its Environment reviewer). Nothing is published by a merge.

The run calls `frontend-ci` and `repo-ci` as jobs, so a red gate on that commit
leaves the publish and deploy jobs *skipped* and the run red. It then compiles
the bundle **once** with `tool/build_web.sh` — the same script `Dockerfile`
runs — deploys it to a Hosting **preview channel**, reads `/release.json` back
off that URL, releases the same bytes to live, and reads it again. Either check
failing fails the run.

`preview_only: true` stops after the preview, which is how to rehearse a change
without going live. **Rollback is Hosting's own release history** (console →
Hosting → Release history → Rollback); this pipeline does not automate it,
because an untested rollback path is not one.

Before the first run, a human has to create the repository *variables*
(`FRONTEND_SITE_URL_DEV` and the four `FIREBASE_*_DEV` — they are public config,
not secrets, ADR-B D-10) and apply the Terraform that grants the deployer
`roles/firebasehosting.admin`. The workflow fails naming each missing variable.
Spec: [`frontend/0017`](../specs/frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md).

The Google button signs in through Firebase's Google provider
(`signInWithPopup`); it answers *operation-not-allowed* until the provider is
enabled once in the console (spec 0008 OD-8). The e-mail button sends a
Firebase sign-in link. Either way the backend then asks its registry whether
that e-mail was invited (`GET /v1/me/access`, spec backend/0027) — the first
admins are `AUTH_BOOTSTRAP_ADMINS`, set for dev in
`infra/environments/dev.tfvars`.

There is no development token any more ([`SECURITY.md`](SECURITY.md) G-1,
closed): whoever signs in is whoever the backend's provisioning registry
says may.

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

Flutter **3.47.5** / Dart **3.13.4**, pinned in [`.fvmrc`](.fvmrc) and **only**
there. `tool/check_toolchain.sh` reads it as the first step of `make gate`, and
`frontend-ci.yaml` reads it to install the SDK; the workflow no longer carries a
`FLUTTER_VERSION` of its own, and `scripts/check_gate_pairs.sh` fails if one
reappears or if a second pin file is added (GGU-94). Using fvm is optional —
nothing shells out to it. One `pubspec.lock` for the whole workspace, enforced
on every install.

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
