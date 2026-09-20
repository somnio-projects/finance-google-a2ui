# CLAUDE.md — finance-google-a2ui

Somnio × Google **A2UI finance showcase** (Jira project `GGU`): an open-source reference app where an AI agent answers portfolio questions by composing UI components instead of text. Monorepo:

| Folder | What | Manual |
|---|---|---|
| `backend/` | FastAPI · Python 3.12 · PostgreSQL · uv — the API and (soon) the A2UI agent host | [`backend/CLAUDE.md`](backend/CLAUDE.md) |
| `client_flutter/` | Flutter workspace (`app/`, `e2e_test/`) · genui 0.10.3 · Bloc — binds the backend's projections and transforms nothing | [`client_flutter/CLAUDE.md`](client_flutter/CLAUDE.md); project rules in `.claude/rules/client/`, generic ones in `.claude/rules/flutter/` |
| `infra/` | Terraform for Google Cloud (ADR-F): private VPC, Cloud SQL, Secret Manager, Cloud Run, logging/alerts — one shape per `environment`, with HA/PITR/Cloud Armor derived **on outside `dev`** (`specs/infra/0001-dev-environment.md`). Validated, applied with GGU-29 | [`infra/README.md`](infra/README.md) |
| `specs/` | Spec-Driven Development — one spec per feature, read before coding | [`specs/README.md`](specs/README.md) |
| `docs/` | `adr/` (decisions), `diagrams/` (Mermaid architecture diagrams), `catalog/` (the **generated** frozen component contract, as Markdown for the designer and JSON for the client test — `make catalog`, never hand-edited), `compliance/` (SOC 2 / ISO 27001), `DEV_HARNESS.md` | [`docs/diagrams/README.md`](docs/diagrams/README.md) |

GitHub `somnio-projects/finance-google-a2ui`. Demo target 2026-09-28.

**Branching:** `develop` is the integration branch — **every PR targets `develop`**. `main` is the release branch and only receives `develop` through a release PR. Branch off `develop` as `type/GGU-n_short_description`.

## Run

```bash
cp backend/env.example backend/.env    # once per clone; env files live in each solution, never committed
docker compose up --build              # Postgres + backend on http://localhost:8000 (docs at /docs)
docker compose --profile client up --build   # …plus the web client on http://localhost:3000
cd client_flutter/app && flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Compose carries only the topology (hostnames, ports, origins); credentials and tunables come from each solution's `.env` through `env_file`. The client is in the stack behind a `client` profile, so a backend-only `docker compose up` never pays for a Flutter build; it is hardened like the backend's container and gets `BACKEND_BASE_URL` at **run** time, not build time (`client_flutter/Dockerfile`, `specs/client/0002-client-delivery.md`).

## Verify — a change is not done without this

```bash
pre-commit install && pre-commit install --hook-type pre-push   # once per clone
cd backend && make gate                # lint · types · budget · catalog contract · quality (smells) · tests 100 % · audit
cd client_flutter && dart format --output=none --set-exit-if-changed . && dart analyze && (cd app && flutter test)
```

`.claude/ship-gate.json` is the Definition of Done and matches CI (`.github/workflows/backend-ci.yaml`) and `make gate` verbatim. Red gate = not done; thresholds are never lowered in a feature PR.

## How work flows (SDD)

`/spec` → human approves the spec → `/feature` (plan → implement by layer → gate → `backend-reviewer` agent → PR) → append `.claude/harness-log.md`. Every PR cites `Spec: specs/<area>/NNNN-….md` and a `Test decision:` line. Details: `.claude/rules/backend/sdd.md`, `docs/DEV_HARNESS.md`.

## Conventions the code does not show

- **The backend shapes every payload; the client transforms nothing** — versioned projections with declared options, selected by the client (`?view=`) or by the agent (validated against the same registry), batched and cached. See `.claude/rules/backend/presentation.md` and `docs/adr/ADR-K-response-shaping.md`.
- **Every endpoint is strictly RESTful and exhaustively documented in OpenAPI** (summary, description, operation_id, tags, response_model, every error response, examples, documented+bounded fields). See `.claude/rules/backend/api-design.md`.
- **Delivery is started by a human and verified by the machine**: `backend-cd.yaml` has **no `push:` trigger** — merging deploys nothing. Someone presses *Run workflow* in the Actions tab and picks the branch, and the branch decides the target (`develop` → **dev**, `main` → production, still behind its required reviewer). The run then pushes the image by digest, deploys a Cloud Run revision with **no traffic**, probes `/readyz`, shifts traffic, checks `/health` reports the release, and **rolls back** otherwise. It calls the ship gate as a job and `needs:` it, so nothing is released without a green gate on that commit. The button only exists because the workflow is on `main` — GitHub reads `workflow_dispatch` from the default branch only. No service-account key: Workload Identity Federation only. The risky logic lives in `infra/scripts/deploy_cloud_run.sh` so it can be tested. See `specs/backend/0007-cd-pipeline.md`.
- **Backend layering is enforced**: controllers only call services; services never import FastAPI/SQLAlchemy; repositories are the only SQLAlchemy users; `bootstrap.py` is the single composition root; files ≤150 lines. See `.claude/rules/backend/architecture.md`.
- **Security is a gate, not a review note**: bearer-token auth on every non-health route, RFC 9457 errors without internals, no secrets/tokens/PII in logs, audit events for identity actions, non-root read-only containers. SOC 2 / ISO 27001 mapping in `backend/docs/SECURITY.md`; rules in `.claude/rules/backend/security.md`.
- **Auth is pluggable**: `AUTH_PROVIDER=jwt` (HS256, dev/service) or `oidc` (RS256 via JWKS — Firebase, Google, any SSO). New provider = one module in `backend/src/app/auth/providers/` + one registry entry.
- **Numbers-from-tools (product invariant)**: the LLM never computes financial figures; deterministic backend tools return pre-formatted `*Display` strings the agent copies. Keep it when the agent lands here.
- Branches `type/short_description` or `type/GGU-n_short_description`, cut from **`develop`**, PRs **into `develop`**; `main` only via release PR. Conventional Commit titles; PRs in English; no AI attribution in commits or PR bodies. The repo allows **squash merges only**.
- Jira `GGU` tickets GGU-3/45/46 were written against the old `backend_python/` sample — treat `specs/backend/0001-backend-foundation.md` as the current baseline and flag divergences in the ticket.

## Do not touch

- `.env`, `.env.*`, keys, service accounts, `google-services.json`, `GoogleService-Info.plist` — denied by permissions. Templates: `backend/env.example`.
- `backend/alembic/versions/*` once merged (add a new revision), `backend/uv.lock` by hand (use `uv add` / `uv lock`).
- `.claude/skills/`, `.claude/rules/python/`, `.claude/rules/flutter/` — synced from `somnio-ai-tools` by the Somnio CLI (`harness.json` records the revision). Project rules live in `.claude/rules/backend/`.
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
| .claude/rules/client/architecture.md | flutter | Client layering, the feature slice, what a Bloc may not do, the 220-line Dart budget (client_flutter/*/lib, client_flutter/CLAUDE.md). |
| .claude/rules/client/presentation.md | flutter | The client half of ADR-K — bind, never format/compute/derive/interpret/invent (client_flutter views, blocs, repositories). |
| .claude/rules/client/testing.md | flutter | Coverage bar and who checks it, unit vs widget vs bloc, the verbatim-binding test, Dart mutation checks (client_flutter/*/test). |
| .claude/rules/client/security.md | flutter | Token handling, what a --dart-define may carry, secrets, logging, TLS, the absent deep-link surface (client_flutter Dart, web shell, manifests). |
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

See `.claude/ship-gate.json` — `cd backend && make gate`.
<!-- somnio:harness:end -->
