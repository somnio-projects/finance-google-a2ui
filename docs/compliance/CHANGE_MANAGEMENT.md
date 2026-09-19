# Change Management and Secure Development Lifecycle

| | |
|---|---|
| **Owner** | TL backend · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC8.1, CC7.1 · ISO/IEC 27001 A.8.25–A.8.29, A.8.31, A.8.32, A.8.9 |

## 1. Lifecycle (Spec-Driven Development)

`/spec` → human approves the spec → `/feature` (plan → implement by layer →
`make gate` → `backend-reviewer` → PR) → CODEOWNERS review → merge → harness
log entry. Details: `docs/DEV_HARNESS.md`, `.claude/rules/backend/sdd.md`,
`specs/README.md`. Security requirements are part of every spec (template
§5) and every controller follows `backend/docs/ADDING_AN_ENDPOINT.md`.

## 2. Environments

| Environment | Purpose | Data | Config source |
|---|---|---|---|
| `local` | development (`docker compose`) | synthetic | `backend/.env` (git-ignored) |
| `test` | CI and integration tests (testcontainers) | ephemeral | `tests/conftest.py::make_settings` |
| `staging` | pre-production deploy, smoke tests (`infra/environments/staging.tfvars`, apply with GGU-29) | synthetic + demo accounts | Secret Manager (`staging` project) |
| `production` | the showcase | demo accounts | Secret Manager (`prod` project) |

Separation is enforced in code: `ENVIRONMENT=production` disables docs/OpenAPI,
requires explicit `TRUSTED_HOSTS`, enables HSTS and admin MFA. Promotion order is
always local → CI → staging → production; a change never lands in production
without a green CI run on the same commit.

## 3. Branch model

| Branch | Role | Who writes to it |
|---|---|---|
| `develop` | integration branch — **every feature/fix PR targets it** | PRs only |
| `main` | release branch — what is deployed and tagged | release PRs from `develop` only |
| `type/GGU-n_…` | one branch per ticket, cut from `develop` | its author |

A release is a PR `develop → main`, squash-merged, tagged, and recorded in
`CHANGELOG.md`. Hotfixes branch from `main`, merge to `main`, and are merged
back into `develop` in the same day.

## 4. Branch protection and review (GitHub ruleset on `main` and `develop`)

- Pull request required; **1 approving review from a code owner** (`.github/CODEOWNERS`); stale approvals dismissed on new commits.
- Required status checks: the four jobs of `.github/workflows/backend-ci.yaml` (exact names below).
- **Squash merges only** (the repository disallows merge commits and rebase merges); force-push and deletion of `main`/`develop` disabled; administrators included.
- The PR template (`.github/pull_request_template.md`) carries the `Spec:` and `Test decision:` lines and the security checklist.

**Current state (enabled and exported 2026-09-19, `evidence/branch-protection-ruleset.json`):**
the ruleset `protected-branches` is **active** on `main` **and** `develop` with
the settings above. Status checks are **not** in the required list on purpose:
the workflows carry `paths:` filters, so a docs-only PR never runs them and a
required check that never runs blocks the merge forever. Reviewers read the
checks that did run; the pre-push hook is what guarantees the gate locally.
The export is refreshed at each internal audit ([isms/INTERNAL_AUDIT_PROGRAM.md](isms/INTERNAL_AUDIT_PROGRAM.md)).
Required-check names must match the job display names exactly:
`gate (ruff · pyright · budget · pytest 100 %)`, `gitleaks`,
`semgrep (python security rules)`, `docker build`.

## 5. Definition of Done

`.claude/ship-gate.json` == `make gate` == CI: ruff, format, basedpyright
strict, 150-line budget, pytest at 100 % branch coverage, pip-audit; plus
gitleaks, Semgrep and the image build/Trivy scan in CI. Thresholds are never
lowered in a feature PR ([EXCEPTION_POLICY.md](EXCEPTION_POLICY.md)).

## 6. Database changes

Only through Alembic revisions in the same PR; merged revisions are immutable
(permission deny in the harness); integration tests run `alembic upgrade head`
on a fresh PostgreSQL; `alembic check` verifies no drift; production
migrations run at container start (`RUN_MIGRATIONS`), preceded by a backup.

## 7. Releases

- `develop` is always green; `main` is always deployable. Releases are tags `vMAJOR.MINOR.PATCH` (SemVer) cut from `main` after a `develop → main` PR, with notes in `CHANGELOG.md` (Keep a Changelog).
- The release PR bumps `backend/pyproject.toml` version (reported by `/healthz`).
- Rollback = redeploy the previous image tag; data rollbacks follow the DR plan.

## 8. Emergency changes

See [EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md). Everything else goes through
this document.

## 9. Dependencies and supply chain

Pinned `uv.lock`; Dependabot weekly (grouped); pip-audit in the gate; Trivy
on the image; weekly scheduled scan with SBOM export; new dependencies named in
the PR with the reason. See [VULNERABILITY_MANAGEMENT.md](VULNERABILITY_MANAGEMENT.md).
