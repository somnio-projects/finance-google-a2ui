# CLAUDE.md — finance-google-a2ui

Somnio × Google **A2UI finance showcase** (Jira project `GGU`): an open-source reference app where an AI agent answers portfolio questions by composing UI components instead of text. Monorepo:

| Folder | What | Manual |
|---|---|---|
| `backend/` | FastAPI · Python 3.12 · PostgreSQL · uv — the API and (soon) the A2UI agent host | [`backend/CLAUDE.md`](backend/CLAUDE.md) |
| `frontend/` | The A2UI client — Flutter 3.47.5 pub workspace (`app/` + five pure-Dart packages, one of them the chart geometry) · Bloc · go_router. Layering, the 150-line budget, the numbers rule and the component seam are all held by its gate (ADR-L). Runs in the stack as a container and ships to Firebase Hosting through `frontend-cd` (spec `frontend/0017`) | [`frontend/CLAUDE.md`](frontend/CLAUDE.md) |
| `infra/` | Terraform for Google Cloud (ADR-F): private VPC, Cloud SQL, Secret Manager, Cloud Run, logging/alerts — one shape per `environment`, with HA/PITR/Cloud Armor derived **on outside `dev`** (`specs/infra/0001-dev-environment.md`). Validated, applied with GGU-29 | [`infra/README.md`](infra/README.md) |
| `specs/` | Spec-Driven Development — one spec per feature, read before coding | [`specs/README.md`](specs/README.md) |
| `docs/` | `adr/` (decisions), `diagrams/` (Mermaid architecture diagrams), `catalog/` (the **generated** frozen component contract, as Markdown for the designer and JSON for the client test — `make catalog`, never hand-edited), `compliance/` (SOC 2 / ISO 27001), `DEV_HARNESS.md` | [`docs/diagrams/README.md`](docs/diagrams/README.md) |

GitHub `somnio-projects/finance-google-a2ui`. Demo target 2026-09-28.

**Branching:** `develop` is the integration branch — **every PR targets `develop`**. `main` is the release branch and only receives `develop` through a release PR. Branch off `develop` as `type/GGU-n_short_description`.

## Run

```bash
cp backend/env.example backend/.env    # once per clone; env files live in each solution, never committed
APP_RELEASE="local+$(git rev-parse --short HEAD)" docker compose up --build   # Postgres + backend on http://localhost:8000 (docs at /docs)
docker compose up --build db backend            # just the API — skips the client's build
```

**One stack, one project: `finance-a2ui`.** `docker compose up` brings up
Postgres, the backend on `:8000` and the A2UI client on `:3001` — everything
this repository is about, under one heading in `docker ps` and in Docker
Desktop, and one `docker compose down` takes it down. The client's container
reports its own build at `GET /release.json`, the same `local+<sha>` the
backend reports at `/health` (spec `frontend/0017`).

There are **no profiles**. The client used to sit behind one, and that made
`docker compose up` mean a different set of services depending on which flag
you remembered. A backend developer who does not want to pay for a Flutter
SDK download names the services instead — `docker compose up db backend` —
which needs no profile to exist.

**Always bring the stack up with `APP_RELEASE`.** `GET /health` reports it
**verbatim** — `core/release.py` composes nothing — and it is the only thing
that says *which build answered*: the field a manual run needs and did not have
when a transcript from a tree six commits behind `develop` was pasted into a
pull request and read exactly like a correct one (GGU-93). The `local+` prefix
is required, not decoration: a bare sha gives `"version":"a1b2c3d"` with no `+`,
which `scripts/check_manual_run.sh` reads as no identity at all. Omit
`APP_RELEASE` entirely and `/health` says `local`, and the check rejects the PR
for naming no build. `repo-ci` runs that check on every pull request.

Working on `frontend/` needs the pinned SDK on `PATH` — Flutter **3.47.5**,
which vendors Dart **3.13.4**. The version lives in `frontend/.fvmrc`
and nowhere else; `cd frontend && make gate` proves it before doing anything
else. Installing it: `frontend/CLAUDE.md` § *Run*.

Compose carries only the topology (hostnames, ports, origins); credentials and tunables come from each solution's `.env` through `env_file`. The client's container is hardened like the backend's — nginx-unprivileged, uid 101, read-only root, no-new-privileges — and its `BACKEND_BASE_URL` is compiled into the bundle at **build** time, because Hosting serves static files and there is no server left to substitute one at run time (`frontend/Dockerfile`, `specs/frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md`).

## Verify — a change is not done without this

```bash
pre-commit install && pre-commit install --hook-type pre-push   # once per clone
cd backend && make gate                # lint · types · budget · catalog contract · quality (smells) · tests 100 % · audit
cd frontend && make gate               # toolchain · format · analyze · budget · manifest · tests · 100 % line coverage
```

Every PR carries a **`Verification` block** that names what was run *and what
was not*, with the reason and the consequence — the field whose absence made an
incomplete verification indistinguishable from a complete one (GGU-93, GGU-94).
The template is in `.claude/rules/backend/sdd.md`, § *The manual run*.

`.claude/ship-gate.json` is the Definition of Done and matches CI (`.github/workflows/backend-ci.yaml`, `frontend-ci.yaml`, `repo-ci.yaml`, `infra-ci.yaml`) and each `make gate` verbatim. It has **four** parts — `py.*`, `infra.*`, `repo.*`, `frontend.*` — and the count is also written in `.claude/rules/ci-conventions.md` §5 and in the file's own `_note`; all three move together. Red gate = not done; thresholds are never lowered in a feature PR.

## How work flows (SDD)

`/spec` → human approves the spec → `/feature` (plan → implement by layer → gate → `backend-reviewer` agent → PR) → append `.claude/harness-log.md`. Every PR cites `Spec: specs/<area>/NNNN-….md` and a `Test decision:` line. Details: `.claude/rules/backend/sdd.md`, `docs/DEV_HARNESS.md`.

## Conventions the code does not show

- **The backend shapes every payload; the client transforms nothing** — versioned projections with declared options, selected by the client (`?view=`) or by the agent (validated against the same registry), batched and cached. See `.claude/rules/backend/presentation.md` and `docs/adr/ADR-K-response-shaping.md`.
- **Every endpoint is strictly RESTful and exhaustively documented in OpenAPI** (summary, description, operation_id, tags, response_model, every error response, examples, documented+bounded fields). See `.claude/rules/backend/api-design.md`.
- **The client ships like the backend, to a different kind of target.** `frontend-cd.yaml` is a button too, calls `frontend-ci` **and** `repo-ci` as jobs so nothing is published without a green gate on that commit, compiles the bundle once with `frontend/tool/build_web.sh` — the same script the container uses, so the two cannot drift — deploys it to a Firebase Hosting **preview channel**, reads `/release.json` back off that URL, releases to live, and reads it again. Hosting has no traffic split, so a preview channel is the `--no-traffic` revision and `/release.json` is the `/health`. Rollback is Hosting's own release history and is deliberately not automated. See `specs/frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md` and `docs/diagrams/13-client-delivery.md`.
- **Delivery is started by a human and verified by the machine**: `backend-cd.yaml` has **no `push:` trigger** — merging deploys nothing. Someone presses *Run workflow* in the Actions tab and picks the branch, and the branch decides the target (`develop` → **dev**, `main` → production, still behind its required reviewer). The run then pushes the image by digest, deploys a Cloud Run revision with **no traffic**, probes `/readyz`, shifts traffic, checks `/health` reports the release, and **rolls back** otherwise. It calls the ship gate as a job and `needs:` it, so nothing is released without a green gate on that commit. The button only exists because the workflow is on `main` — GitHub reads `workflow_dispatch` from the default branch only. No service-account key: Workload Identity Federation only. The risky logic lives in `infra/scripts/deploy_cloud_run.sh` so it can be tested. See `specs/backend/0007-cd-pipeline.md`.
- **Backend layering is enforced**: controllers only call services; services never import FastAPI/SQLAlchemy; repositories are the only SQLAlchemy users; `bootstrap.py` is the single composition root; files ≤150 lines. See `.claude/rules/backend/architecture.md`.
- **`frontend/` layering is enforced the same way, by a test**: pure-Dart packages cannot import Flutter, blocs never touch the transport, `bootstrap.dart` is the single composition root, and `NumberFormat`/`dart:math`/`DateTime.now()` are absent from `lib/` — `app/test/architecture/layering_test.dart` fails on the mechanism. **Charts are primitives, not a library**: `fl_chart` and `graphic` format their own axis labels, which breaks the numbers invariant inside a dependency, so `packages/finance_charts` ports the arithmetic worth having from d3 and `app/lib/charts/` paints it (ADR-L D-13). **Adding a component edits no existing file**; the wiring is a generated, gated manifest. See ADR-L and `.claude/rules/frontend/`.
- **One Flutter app: `frontend/`.** There were two. `client_flutter/` was the older one, still largely Google's upstream `restaurant_finder` sample, and it was deleted on 2026-09-22 with its gate, its workflow, its rules and its compose file (spec `specs/repo/0002-retire-the-client-flutter-app.md`). Its specs and ADR-I are **superseded, not erased** — a spec that shipped stays in place with a pointer. If a second app ever returns it gets its own gate part, its own `<area>-ci.yaml` row and its own specs area, never a job bolted onto `frontend-ci`.
- **Security is a gate, not a review note**: bearer-token auth on every non-health route, RFC 9457 errors without internals, no secrets/tokens/PII in logs, audit events for identity actions, non-root read-only containers. SOC 2 / ISO 27001 mapping in `backend/docs/SECURITY.md`; rules in `.claude/rules/backend/security.md`.
- **Auth is pluggable**: `AUTH_PROVIDER=jwt` (HS256, dev/service) or `oidc` (RS256 via JWKS — Firebase, Google, any SSO). New provider = one module in `backend/src/app/auth/providers/` + one registry entry.
- **Numbers-from-tools (product invariant)**: the LLM never computes financial figures; deterministic backend tools return pre-formatted `*Display` strings the agent copies. Keep it when the agent lands here.
- Branches `type/short_description` or `type/GGU-n_short_description`, cut from **`develop`**, PRs **into `develop`**; `main` only via release PR. Conventional Commit titles; PRs in English; no AI attribution in commits or PR bodies. The repo allows **squash merges only**.
- Jira `GGU` tickets GGU-3/45/46 were written against the old `backend_python/` sample — treat `specs/backend/0001-backend-foundation.md` as the current baseline and flag divergences in the ticket.

## Do not touch

- `.env`, `.env.*`, keys, service accounts, `google-services.json`, `GoogleService-Info.plist` — denied by permissions. Templates: `backend/env.example`.
- `backend/alembic/versions/*` once merged (add a new revision), `backend/uv.lock` by hand (use `uv add` / `uv lock`).
- `.claude/skills/`, `.claude/rules/python/`, `.claude/rules/flutter/` — synced from `somnio-ai-tools` by the Somnio CLI (`harness.json` records the revision). Project rules live in `.claude/rules/backend/` and `.claude/rules/frontend/`.
- `frontend/pubspec.lock` by hand, and `frontend/app/lib/components/component_manifest.g.dart` (generated — run `cd frontend && make manifest`).
- The coverage `fail_under`, ruff rule set and `typeCheckingMode` — team decisions, not fixes.

<!-- somnio:harness:begin -->
> This block is regenerated by `/harness-init` on every run — edits made inside it are lost
> the next time it runs. Write anything you want kept in the section above.

## Stacks detected

flutter, python

## Rules

Rule bodies are never inlined here — only the index. Each row loads lazily, only when the
matching path is touched.

| path | stack | loads when |
|:--|:--|:--|
| .claude/rules/backend/architecture.md | python | Backend layering, file templates, 150-line budget (backend/src, backend/tests). |
| .claude/rules/backend/api-design.md | python | REST semantics, exhaustive OpenAPI documentation, DRY/abstraction (backend/src/app/api, schemas). |
| .claude/rules/backend/presentation.md | python | Projections, declared options, A2UI adapters, batching and caching (backend/src/app/presentation). |
| .claude/rules/diagrams.md | all | Architecture diagrams as Mermaid in docs/diagrams/, updated in the same PR as the structure they describe. |
| .claude/rules/ci-conventions.md | all | Where a check belongs (pre-commit vs CI), job/step naming, CI cost rules (.github/, .pre-commit-config.yaml). |
| .claude/rules/backend/security.md | python | SOC 2 / ISO 27001 controls while writing backend code, Dockerfile, compose. |
| .claude/rules/backend/testing.md | python | 100 % branch coverage contract, unit vs integration, fixtures and naming. |
| .claude/rules/backend/sdd.md | all | Spec-driven workflow, harness log, `/feature` lifecycle (specs/, .claude/). |
| .claude/rules/frontend/architecture.md | flutter | `frontend/` layering, the composition root, the component seam, the 150-line budget. |
| .claude/rules/frontend/contract-binding.md | flutter | The numbers rule and the fifteen prohibitions; view ids, options, ETags (frontend components, repository, transport). |
| .claude/rules/frontend/testing.md | flutter | `frontend/` coverage contract, the pump_app harness, what a test must assert. |
| .claude/rules/python/code-style.md | python | Ruff gate, naming, imports, Google docstrings. |
| .claude/rules/python/data-validation.md | python | pydantic at boundaries, pydantic-settings, typed responses. |
| .claude/rules/python/error-handling.md | python | EAFP, narrowest except, custom hierarchy, translate at boundaries. |
| .claude/rules/python/function-design.md | python | Single responsibility, early returns, pure functions, keyword-only args. |
| .claude/rules/python/module-structure.md | python | src/ layout, layered architecture, Protocols, composition root, structlog. |
| .claude/rules/python/testing-integration.md | python | DB fixture isolation, markers, branch coverage gate. |
| .claude/rules/python/testing-unit.md | python | pytest conventions, fixtures, parametrize ids, mocker autospec. |
| .claude/rules/python/typing.md | python | Type hints everywhere, modern generics, pyright strict, py.typed. |
| .claude/rules/flutter/architecture.md | flutter | General architecture guidelines when using Flutter. |
| .claude/rules/flutter/best-practices.md | flutter | Flutter principles, workflow, testing standards, documentation. |
| .claude/rules/flutter/bloc-test.md | flutter | Bloc testing standards. |
| .claude/rules/flutter/code-patterns.md | flutter | Dart/Flutter implementation patterns. |
| .claude/rules/flutter/layout.md | flutter | Flutter layout patterns. |
| .claude/rules/flutter/testing.md | flutter | Flutter/Dart testing best practices. |
| .claude/rules/flutter/ui-theming.md | flutter | Material 3 theming, ThemeExtension, accessibility. |

## Verification commands

See `.claude/ship-gate.json` — `cd backend && make gate` and `cd frontend && make gate`.
<!-- somnio:harness:end -->
