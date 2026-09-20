# CI and pre-commit conventions

Applies to every workflow in `.github/workflows/` and to
`.pre-commit-config.yaml`. Two goals, in this order: **a reader understands the
run at a glance**, and **we do not pay CI minutes for what a laptop can prove**.

## 1. Where a check belongs

| Prove it… | …here | Why |
|---|---|---|
| Formatting, lint, types, file budget, complexity, dead code, duplication, docstrings, typos, unit tests, secrets in the diff, `terraform fmt`, workflow syntax | **pre-commit** (`pre-commit install`) | instant feedback, zero CI cost |
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

**Backend.** `make gate` == pre-push == CI, in this order: `lint` (ruff check +
format), `typecheck` (basedpyright strict), `budget` (150 lines), `quality`
(xenon complexity · vulture dead code · interrogate 100 % docstrings · deptry
dependency hygiene · pylint duplication and design limits · codespell), `test`
(pytest, 100 % branch coverage), `audit` (pip-audit). Thresholds live in
`backend/pyproject.toml`; they go **up**, never down, and never in a feature PR.

**Client.** `dart format --set-exit-if-changed` and `dart analyze
--fatal-infos --fatal-warnings`, both **over `app/lib app/test e2e_test`,
never a bare `.`**. `flutter pub get` unpacks plugin sources under
`app/build/` — firebase_auth ships its own tests through Swift Package
Manager — and those trees carry **their own `pubspec.yaml`**, which makes each
of them a separate package root. That is why `analysis_options.yaml`'s
`exclude: ["**/build/**"]` does **not** cover them (it only reaches inside our
own package, and it is kept for the IDE) and why `dart format` cannot be
fixed at all from config: it has no exclude flag. Passing the source
directories is the only thing that holds for both, so both commands carry the
same list and it is one decision. Symptom when this regresses: hundreds of
foreign lints and reformatted files nobody wrote. Then the two grep gates
(`tool/check_tokens.sh` — no colour literals outside `theme/`;
`tool/check_config.sh` — no endpoint URLs outside `config/`), `flutter test
--coverage`, and `flutter build web --release`. The grep gates guard
architecture rather than style, which is why they are gates and not review
notes. The Flutter SDK is pinned in `client_flutter/.fvmrc`; CI reads the same
version, and bumping one without the other makes local and CI disagree
silently.

## 5. When you change one, change its pair

`.claude/ship-gate.json` is the Definition of Done and has three parts, each
with a runner and a workflow that must stay identical to it:

| Part | Runner | Workflow | Also in |
|---|---|---|---|
| `py.*` | `cd backend && make gate` | `backend-ci.yaml` | pre-commit (the cheap steps) + pre-push (the whole gate) |
| `dart.*` · `client.*` · `flutter.*` | the entries themselves, from `client_flutter/` and `client_flutter/app/` — there is no client Makefile | `client-ci.yaml` | pre-commit (format, analyze, grep gates, tests) + pre-push (the web build) |
| `infra.*` | `bash infra/scripts/tests/*.sh` from the repository root — there is no root Makefile | `infra-ci.yaml` (`delivery-scripts`) | pre-commit |

A PR that changes one without its pair is incomplete. If a fourth runner ever
appears, it goes in this table rather than in a comment.
