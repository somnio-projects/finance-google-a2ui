# CI and pre-commit conventions

Applies to every workflow in `.github/workflows/` and to
`.pre-commit-config.yaml`. Two goals, in this order: **a reader understands the
run at a glance**, and **we do not pay CI minutes for what a laptop can prove**.

## 1. Where a check belongs

| Prove it… | …here | Why |
|---|---|---|
| Formatting, lint, types, file budget, freshness of a generated artefact, complexity, dead code, duplication, docstrings, typos, unit tests, secrets in the diff, `terraform fmt`, workflow syntax | **pre-commit** (`pre-commit install`) | instant feedback, zero CI cost |
| Full `make gate` including the DB-backed suite | **pre-push** hook | catches it before it ever reaches a runner |
| The same checks on a clean machine, integration tests against a real PostgreSQL, container build + CVE scan, secret scan over the **full history**, dependency CVEs | **CI** | a laptop cannot guarantee these |
| Anything slow, scheduled or org-wide (weekly scans, SBOM) | **scheduled workflow** | keeps the PR path fast |

A new check is added to pre-commit **first**. It goes to CI only if it needs
something the developer's machine cannot provide, or if it must be proven on a
clean checkout.

## 2. Naming contract

- **Workflow file**: `<area>-ci.yaml` (`backend-ci`, `infra-ci`), plus purpose-named ones (`scheduled-scan`).
- **Job name**: `"<Area> · <what it proves>"` — *what it proves*, never the tool list.
  `"Tests · pytest with 100% branch coverage on PostgreSQL 16"`, not `"pytest"`.
- **Step name**: `"<Verb> <object> (<tool>)"` — imperative verb, the object in plain words, the tool in parentheses.
  `"Audit the locked runtime dependencies for CVEs (pip-audit)"`, not `"py.audit"` or `"Run make audit"`.
- Every job ends in a `Report · …` job that writes a table to `$GITHUB_STEP_SUMMARY`, so the run is readable without opening a log.
- Never leave a bare `- uses:` without a `name:`.

## 3. Cost rules

- `concurrency: cancel-in-progress` on every workflow, keyed by ref.
- `paths:` filters so a docs-only change does not start a build.
- `timeout-minutes` on every job (no runaway runners).
- Expensive jobs (`image`, deploy) declare `needs:` on the cheap ones — a branch that fails lint never pays for a build.
- Cache the dependency install (`setup-uv` with `cache-dependency-glob`), use `cache-from/to: type=gha` for Docker layers.
- Prefer a **service container** over starting containers inside the job (testcontainers) when CI supports it.
- Artifacts get an explicit `retention-days` (14 for coverage, 90 for security evidence).
- Pin every action to a released tag and every tool image to a version — a floating tag is both a supply-chain risk and a cache miss.

## 4. Quality gates the project keeps

`make gate` == pre-push == CI, in this order: `lint` (ruff check + format),
`typecheck` (basedpyright strict), `budget` (150 lines), `quality`
(xenon complexity · vulture dead code · interrogate 100 % docstrings · deptry
dependency hygiene · pylint duplication and design limits · codespell), `test`
(pytest, 100 % branch coverage), `audit` (pip-audit). Thresholds live in
`backend/pyproject.toml`; they go **up**, never down, and never in a feature PR.

`catalog-check` sits between `budget` and `quality`: it re-renders **every**
generated catalog artefact — `docs/catalog/CONTRACT.md` (GGU-41, spec
`backend/0019`) and `docs/catalog/view-catalog.snapshot.json` (GGU-53, spec
`backend/0021`) — from the projection registry into a buffer and diffs each
against the checked-in file. One command, one render pass: a new artefact is an
entry in `presentation/catalog_artifacts.ARTIFACTS`, not a new gate step, so
`ship-gate.json` and the workflows keep matching verbatim.

**A generated artefact is gated by regeneration, never by trust.** Anything the
build produces is checked in *and* re-rendered by the gate and diffed, and the
check fails with the exact command that fixes it. A second such artefact copies
that shape rather than relying on a reviewer remembering to look.

## 4b. One pipeline per stack, and delivery is a button

**Nothing runs on a merge.** `backend-ci` has no `push:` trigger (it would run
the same gate twice on the same commit) and `backend-cd` has none either —
delivery is `workflow_dispatch` only. The cost model for this project is: pay
on pull requests, where a regression is actually caught, and pay for a deploy
when somebody asks for one.

That is safe only because `develop` is branch protected, so every change
arrives through a pull request and is gated there. If protection is ever
removed, the push triggers have to come back with it.

**A change to one stack must not start the other stack's pipeline.** Every
workflow is scoped by `paths:` to the directory it proves:

| workflow | runs on | scope |
|---|---|---|
| `backend-ci` | pull requests | `backend/**`, `docs/catalog/**`, `docker-compose.yml`, its own file |
| `client-ci` | pull requests | `client_flutter/**`, its own file |
| `infra-ci` | pull requests | `infra/**`, the delivery workflows |
| `backend-cd` | **the button only** | — |

A new stack gets its own `<area>-ci.yaml` with its own `paths:`. Adding jobs to
an existing workflow so that "everything runs together" is the thing this table
exists to prevent: a Dart formatting fix must never pay for a PostgreSQL
container, and a Python change must never wait on a Flutter build.

**The button lives on the default branch.** GitHub reads `workflow_dispatch`
from the default branch only, so a delivery workflow that exists only on
`develop` is invisible in the Actions tab and `gh workflow run` answers *"not
found on the default branch"*. Releasing `develop` into `main` is what makes
the button appear.

## 5. When you change one, change its pair

`.claude/ship-gate.json` is the Definition of Done and has two halves, each
with a runner and a workflow that must stay identical to it:

| Half | Runner | Workflow | Also in |
|---|---|---|---|
| `py.*` | `cd backend && make gate` | `backend-ci.yaml` | pre-commit (the cheap steps) + pre-push (the whole gate) |
| `infra.*` | the `infra.*` commands from the repository root — there is no root Makefile | `infra-ci.yaml` (`delivery-scripts`) | pre-commit |
| `repo.*` | the `repo.*` commands from the repository root | `repo-ci.yaml` | pre-commit |

**`repo-ci.yaml` deliberately has no `paths:` filter**, which every other
workflow here does have. A repository-wide check placed in a scoped workflow
runs only when that scope changes — exactly when it is least needed. It is
seconds long, so running it on every pull request costs nothing worth saving.
A new `repo.*` check belongs here only if it genuinely spans the repository;
anything that proves one stack goes in that stack's workflow.

**"Identical" means the command, not the intent.** `infra.shell-lint` was
missing from `ship-gate.json` while `infra-ci` had been running
`shellcheck infra/scripts/deploy_cloud_run.sh infra/scripts/tests/*.sh` all
along. Both halves were individually sensible and nobody compared them, so a
shellcheck finding **in a test script** passed every local check and failed on
a runner — after the branch had already merged.

The lesson is narrow and worth keeping: when you add a check to a workflow,
copy its command string into `ship-gate.json` rather than describing what it
does. A paraphrase is where the two drift.

**`repo.spelling` is the second instance of the same defect**, found while
renumbering a spec. `make gate` ran `codespell src tests docs scripts` from
inside `backend/`; the pre-commit hook ran codespell over the whole
repository. Both were individually sensible and nobody compared them, so a
typo in `specs/`, root `docs/` or `.claude/` **passed a green gate** and was
caught only at commit time — and only if the author had not bypassed the hook.
Proven both ways: a typo added to `specs/README.md` exits 65 under the new
check and exits 0 under the old scope.

The two halves also disagreed on *configuration*, not just scope: the hook
read `backend/pyproject.toml`, whose word list knows nothing about the Flutter
or documentation vocabulary, so it flagged `bloc` on every Flutter file it
touched. Both now read `.codespellrc`. **Two configurations for one check is
the same drift as two command strings.**

A PR that changes one without its pair is incomplete. If a third runner ever
appears, it goes in this table rather than in a comment.
