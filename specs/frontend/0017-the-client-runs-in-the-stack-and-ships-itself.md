# 0017 — The client runs in the stack and ships itself

- **Area:** frontend (with the root compose file, two workflows and one IAM grant)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [infra/0002](../infra/0002-firebase-sign-in-on-dev.md) (Hosting became the client's target), [frontend/0001](0001-frontend-skeleton.md) (the gate), [frontend/0008](0008-sign-in.md) (Firebase is the provider), [backend/0007](../backend/0007-cd-pipeline.md) (the delivery shape this copies), [backend/0027](../backend/0027-user-provisioning.md) OD-3 (the preview sign-in a Firebase-less build falls back to), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) D-10 (the web config is public), [`.claude/rules/ci-conventions.md`](../../.claude/rules/ci-conventions.md) §4b and §5
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The A2UI client became a deployed web app under `infra/0002` — Hosting serves
it, a human builds it on a laptop and a human runs `firebase deploy`. Three
things were then true and none of them was written down anywhere:

- **The stack could not run the app this repository is about.** The root
  `docker-compose.yml` had a `client` profile for `client_flutter/`, the older
  app, and nothing for `frontend/`. A reviewer who wanted to see the A2UI
  client had to install a pinned Flutter SDK first; there was no `docker
  compose up` that produced it.
- **Delivery was a laptop.** Every property `backend-cd` exists to guarantee —
  the gate ran on the commit being released, one artifact built once and
  verified before users reach it, an answer to *which build is live* — was
  absent for the client, and the thing being published is the half a user
  actually looks at.
- **Hosting served the container's bundle with none of the container's
  headers.** `frontend/docker/`'s CSP, COOP and the rest were about to be
  written; `firebase.json` had no `headers` block at all, so the hardening
  would have been real on a laptop and absent in the only place anyone reaches.

Two defects were found while building this and are fixed here because the work
could not be honest otherwise; both are recorded as rulings below (OD-6, OD-7).

## 2. What ships

| Where | Change |
|---|---|
| `frontend/Dockerfile` + `frontend/docker/` | builder (SDK from `.fvmrc`, verified by checksum) + `nginx-unprivileged` runtime, non-root, read-only FS, rendered CSP |
| `frontend/tool/build_web.sh` | the ONE home of the `flutter build web` flags; writes `/release.json`. Called by the Dockerfile and by `frontend-cd` |
| `frontend/tool/verify_release.sh` + `tool/tests/test_verify_release.sh` | ask a deployed origin which build it serves; the suite proves it rejects |
| `frontend/.dockerignore` | keeps `app/build/`, `.dart_tool/` and a developer's `firebase.json` out of the context |
| `docker-compose.yml` | a `frontend` service on `:3001` behind a `frontend` profile; `:3001` added to the backend's CORS |
| `.github/workflows/frontend-cd.yaml` | the button: gate → bundle → preview channel → verify → live → verify |
| `.github/workflows/frontend-ci.yaml` | `workflow_call`, the new suite, `docker-compose.yml` in `paths:` |
| `firebase.json` | `headers` — the container's header set, header for header |
| `infra/main.tf`, `infra/delivery.tf` | the two Firebase APIs; `roles/firebasehosting.admin` for the existing deployer |
| `.claude/ship-gate.json`, `frontend/Makefile`, `.pre-commit-config.yaml` | `frontend.verify-release-test`, in all three places at once |
| `scripts/check_gate_pairs.sh` | rule 3 — an app's Dockerfile may not name a Flutter version and must `COPY` the pin |
| `client_flutter/Dockerfile` + `client_flutter/docker/flutter-sdk-checksums.json` | reads its own `.fvmrc` (OD-7) |
| `infra/scripts/tests/test_dev_environment.sh` | the client's delivery shape, asserted |
| `.claude/rules/ci-conventions.md` | the merge conflict it has carried since PR #26, resolved (OD-6); `frontend-cd` in §4b; the Frontend paragraph in §4 |

## 3. Rulings

- **OD-1 — the client's configuration is compiled in, and the image is
  per-environment.** `client_flutter/Dockerfile` argues the opposite (its
  Decision 1): render `/config.json` at start so one image is promotable by
  digest. That argument is correct *for a container that is the deployable*,
  and this app's deployable is a Hosting release — a static bundle, with no
  process to render anything. The seam agrees: `AppConfig` is the only reader
  of `String.fromEnvironment` and `layering_test.dart` fails any second one, so
  a runtime loader is not a flag but a second configuration path through a
  layer that deliberately has one. **Cost, stated:** "promote the digest" is
  not available to this app. **Mitigation:** the run verifies the bundle it
  published by reading `/release.json` off the origin — verification after the
  fact instead of identity before it (OD-4).

- **OD-2 — one build script, two consumers.** The `flutter build web` flags
  live in `frontend/tool/build_web.sh` and nowhere else. `repo.gate-pairs`
  cannot compare the Dockerfile with the workflow — neither is a ship-gate
  command — so this is the one place where §5's drift has no machine check and
  the only defence is not writing the list twice.

- **OD-3 — a preview channel is the client's `--no-traffic` revision.** Hosting
  has no traffic split, but a preview channel is a complete deploy of the same
  bytes at an address no user is sent to. `frontend-cd` deploys there first,
  reads `/release.json` back **over HTTP**, and only then releases to live.
  One compile: the deploy job downloads the publish job's artifact rather than
  re-building, so the bytes verified are the bytes released.

- **OD-4 — `/release.json` is the client's `/health`.** GGU-93's finding was
  that evidence had no field for *which build answered*. A static bundle cannot
  be asked, so `build_web.sh` writes the answer beside it and the pipeline reads
  it back. It is `no-store` in both the container and `firebase.json`, for the
  same reason `/health` is never cached.
  **Rollback is NOT automated and is not claimed to be.** Hosting keeps its own
  release history (console, or `firebase hosting:clone`); an untested rollback
  path is not a rollback path (backend/0007, same rule). What this pipeline
  guarantees is that a failed release is loud.

- **OD-5 — three header differences from `client_flutter`, each measured.**
  `script-src` names `www.gstatic.com` (the Firebase JS SDK is injected from
  there at run time — three references in the built `main.dart.js`);
  `Cross-Origin-Opener-Policy` is `same-origin-allow-popups`, because
  `same-origin` severs the `window.opener` handle `signInWithPopup` resolves
  on; and `connect-src` — **not `font-src`** — names `fonts.gstatic.com`,
  because CanvasKit `fetch()`es fallback-font bytes and installs them through
  `FontFace`. The third was found by reading the console of this container,
  signed in, on 2026-09-22: without it the page renders and the console
  carries a violation per font. A policy that is violated on every load is a
  policy nobody reads. `client_flutter`'s template has the same gap and is not
  touched here — its app is not this ticket.

- **OD-6 — `.claude/rules/ci-conventions.md` had unresolved merge-conflict
  markers on `develop`.** Two regions, introduced by `f4fa557` (PR #26) and
  untouched since: the **Client** gate paragraph on one side, §4b and most of
  §5 on the other. Both sides were wanted; the merge simply never happened.
  Resolved by keeping both, because the file this PR has to edit is the file
  that defines "change one, change its pair" — editing around a conflict marker
  in it was not an option. Two stale counts went with it: §5 said the gate "has
  three parts" and warned about "a fourth runner" when there are five.

- **OD-7 — `client_flutter/Dockerfile` pinned a different SDK than
  `client_flutter/.fvmrc`, and the check could not see it.** `ARG
  FLUTTER_VERSION=3.47.5` against a `.fvmrc` of **3.47.3**: the image shipped a
  bundle compiled by an SDK the gate never proved that app against. This is
  GGU-94's defect a fourth time, and the first instance in a file
  `scripts/check_gate_pairs.sh` was not reading — it greps workflows for
  `FLUTTER_VERSION:` and checks a fixed list of pin files, and a Dockerfile is
  neither. Found by writing the same builder stage for `frontend/` and asking
  where its version would live.
  Rule 3 is the answer, with **two** assertions because either alone is
  satisfiable by the wrong file: an app's Dockerfile may not name a version,
  **and** must be shown to `COPY` the pin in. The first draft grepped for the
  string `.fvmrc` and was satisfied by an error message that merely contained
  it — caught by mutating the file and watching the check stay green.
  Editing `client_flutter/` from a `frontend/` spec breaks the root
  `CLAUDE.md`'s "never edit one from the other's ticket", **deliberately and
  narrowly**: the change is a repository-wide invariant, not a client feature,
  and a check that cannot be green is not a check. The alternative — ship rule
  3 red, or ship it not covering the app that already violates it — is worse.

- **OD-8 — the Firebase web config is a repository *variable*, not a secret.**
  It is public by design (ADR-B D-10) and reaches every browser in the bundle.
  Putting it in secrets would imply otherwise and would mask it out of the logs
  that make a build reviewable. `frontend-cd` names each missing variable
  exactly as a human must create it.

- **OD-9 — the client keeps its own profile in compose.** `docker compose up`
  is still Postgres + backend: building a Flutter bundle downloads an SDK and a
  backend developer should never pay for it. Two profiles rather than one,
  because the two apps are separate deployables and bringing up the one you are
  not working on is pure cost. `COMPOSE_PROFILES=frontend,client` gets
  everything, all of it under the one project name `finance-a2ui`.

## 4. Acceptance criteria

1. **AC-1** — `docker compose --profile frontend up --build` serves the A2UI client on `:3001`, under project `finance-a2ui`, non-root and read-only, and its `/health` answers `ok`.
2. **AC-2** — that container's bundle signs in against the stack's backend and renders the home screen, with **no** CSP violation in the console.
3. **AC-3** — `GET /release.json` on the container reports `local+<sha>` when the stack was brought up with `APP_RELEASE`, and is served `no-store`.
4. **AC-4** — the image's Flutter version comes from `frontend/.fvmrc`; a version with no checksum row stops the build and names the row to add.
5. **AC-5** — `frontend-cd` runs `frontend-ci` and `repo-ci` as jobs, and `publish`/`deploy` `needs:` both, so a red gate leaves them skipped and the run red.
6. **AC-6** — `frontend-cd` deploys to a preview channel, verifies `/release.json` there, releases to live, and verifies again; `preview_only` stops after the first verification.
7. **AC-7** — `frontend-cd` has no `push:` trigger; `develop` releases dev and `main` releases production behind its Environment reviewer.
8. **AC-8** — `frontend.verify-release-test` is in `ship-gate.json`, in `make gate`, in `frontend-ci` verbatim and in pre-commit, and `repo.gate-pairs` is green.
9. **AC-9** — `repo.gate-pairs` fails on a Dockerfile that names a Flutter version, and on one that does not `COPY` its `.fvmrc`. Both mutation-tested.
10. **AC-10** — `firebase.json` serves the container's header set, and `/release.json` `no-store`.
11. **AC-11** — `.claude/rules/ci-conventions.md` contains no conflict marker and lists `frontend-cd` in §4b.

## 5. Test plan

| AC | How |
|---|---|
| 1, 3 | build and run the image; `curl` `/health` and `/release.json` with headers |
| 2 | browser: sign in with `demo@somnio.dev`, read the console |
| 4 | `.fvmrc` bumped to an unknown version → the build stops with the checksum message |
| 5, 6, 7 | `infra/scripts/tests/test_dev_environment.sh` — the `needs:` edges, the environments, the preview channel, the identity check, the absent `push:` |
| 8 | `bash scripts/check_gate_pairs.sh` |
| 9 | mutate each half of rule 3, watch it go red, revert |
| 10, 11 | read the files; `bash scripts/check_spelling.sh` and `actionlint` over both workflows |
| the delivery check itself | `frontend/tool/tests/test_verify_release.sh` — seven rejections, one acceptance, and an anti-vacuity guard |

## 6. Out of scope

- **A production Hosting site.** `firebase.json` is static and there is one site, so its CSP names the dev API origin literally. A second environment needs `hosting` to become a list with a `target` each; `frontend-cd` fails on the missing `FRONTEND_SITE_URL_PRODUCTION` before it can publish a production bundle behind a dev policy.
- **Automated Hosting rollback** — OD-4.
- **`client_flutter`'s CSP** — OD-5; the `fonts.gstatic.com` gap is real there too and belongs to that app's owner.
- **Repository variables and the Terraform apply.** Both are a human's button: `FRONTEND_SITE_URL_DEV` and the four `FIREBASE_*_DEV` variables have to exist, and `roles/firebasehosting.admin` has to be applied, before the first run. The workflow fails with the exact variable names if they are not.
