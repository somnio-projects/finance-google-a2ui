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
| `dev` | the deployed proof of concept — what `develop` releases (`infra/environments/dev.tfvars`, apply with GGU-29) | **synthetic only** | Secret Manager (`finance-a2ui` project) |
| `staging` | pre-production deploy, smoke tests (`infra/environments/staging.tfvars`) — **defined but not provisioned, and currently nobody's deploy target** | synthetic + demo accounts | Secret Manager (`staging` project) |
| `production` | the showcase | demo accounts | Secret Manager (`prod` project) |

`dev` is a reduced control set, not a smaller production — the controls it does
**not** have are listed in
[specs/infra/0001-dev-environment.md](../../specs/infra/0001-dev-environment.md)
§5 and in each control's own document here. It holds synthetic data only; that
constraint is what makes the reduction acceptable.

Separation is enforced in code: `ENVIRONMENT=production` disables docs/OpenAPI,
requires explicit `TRUSTED_HOSTS`, enables HSTS and admin MFA. Promotion order is
always local → CI → dev → production; a change never lands in production
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
- One active exception, **EX-1** in [EXCEPTION_POLICY.md](EXCEPTION_POLICY.md): the admin role may merge its own PR while the second code owner onboards (expires 2026-10-03). The PR itself is still mandatory.
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
- The release PR bumps `backend/pyproject.toml` version. `GET /healthz` reports the **release identifier** `<version>+<short sha>`, injected as `APP_RELEASE` by the pipeline, so the running revision names the exact commit it was built from.
- **Deployment is automated, gated and recorded** (`.github/workflows/backend-cd.yaml`, spec 0007, `specs/infra/0001-dev-environment.md`). A merge to `develop` releases **dev** with no human step; a merge to `main` releases production only after the `production` GitHub Environment's **required reviewer** approves — the separation-of-duties control for release, since the approver need not be the merger. In both cases the delivery run **calls the full ship gate as a job and the build and deploy jobs `needs:` it**, so nothing is published or released unless the gate passed on that exact commit; this is a dependency inside one run, not a notification that fires after CI and then has to remember to check whether it passed.
- **The deploy record is the workflow run.** Its summary names the environment, the commit, the release identifier, the **image digest** and the Cloud Run revision, and the GitHub Environment keeps the deployment history. No separate spreadsheet: the record cannot drift from what actually ran.
- **Nothing takes traffic unverified.** The revision is created with no traffic (its startup applies the migrations), `/readyz` is probed on that revision, traffic shifts only then, and `/healthz` must report the expected release.
- **Rollback is automatic on a failed verification** — traffic returns to the previously serving revision and the run fails. A manual rollback is the same script with `ROLLBACK_TO=<revision>`, or re-running `backend-cd` with the `rollback_to` input (`infra/README.md`). Data rollbacks follow the DR plan.
- **The pipeline holds no long-lived credential.** GitHub Actions authenticates to Google Cloud with Workload Identity Federation, and the provider only accepts tokens whose `repository` claim is this repository. A test in `infra-ci` fails the build if a service-account key resource is ever added.

## 8. Emergency changes

See [EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md). Everything else goes through
this document.

## 9. Dependencies and supply chain

Pinned `uv.lock`; Dependabot weekly (grouped); pip-audit in the gate; Trivy
on the image; weekly scheduled scan with SBOM export; new dependencies named in
the PR with the reason. See [VULNERABILITY_MANAGEMENT.md](VULNERABILITY_MANAGEMENT.md).
