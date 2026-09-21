# 0007 — Continuous delivery: build, publish, deploy, verify, roll back

- **Area:** backend (pipeline + infrastructure)
- **Status:** Approved
- **Ticket:** [GGU-48](https://somniosoftware.atlassian.net/browse/GGU-48) · **Related:** [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md) (Cloud Run + Cloud SQL), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md), `.claude/rules/ci-conventions.md`, `docs/compliance/CHANGE_MANAGEMENT.md`, `docs/compliance/ACCESS_CONTROL.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

`infra/` already describes the entire production topology in Terraform and
`backend-ci` already builds and scans the container image, but **nothing
publishes that image and nothing deploys it**. GGU-29 stops at
`terraform apply`; the gap between "the gate is green" and "the change is
running" is filled today by a human with a laptop, which is exactly what
`docs/compliance/CHANGE_MANAGEMENT.md` says must not happen. For a showcase
whose demo date is fixed, an unrepeatable deploy is a schedule risk as much as
a control gap.

Two further gaps follow from the same hole. There is no published identity for
GitHub Actions to assume, so the first person to wire a deploy would reach for
a long-lived service-account key in a repository secret. And the running
service cannot say **which** build it is: `/health` reports the hard-coded
package version, so a revision that failed to update looks identical to one
that succeeded.

## 2. Scope

**In**

- An **Artifact Registry** Docker repository in `infra/`, with an immutable
  `:<git-sha>` tag per build plus a moving `:develop` / `:main` tag.
- **Workload Identity Federation** from this GitHub repository to Google Cloud:
  a pool, a provider constrained to this repository, and a **deployer service
  account** with the narrowest roles that can publish and deploy. No key
  material anywhere.
- `.github/workflows/backend-cd.yaml` — build, push, deploy, verify, record.
  `develop` → **dev**, started by hand from the Actions tab (retargeted from staging by
  `specs/infra/0001-dev-environment.md`); `main` → production behind a
  `production` GitHub Environment with a required reviewer.
- A **deploy-and-verify script** (`infra/scripts/deploy_cloud_run.sh`) holding
  the risky logic — deploy without traffic, confirm the revision is Ready,
  shift traffic, verify the release, roll back on failure — so the behaviour is
  testable without a cloud account.
- **Release identity**: `APP_RELEASE` reaches the container, and `/health`
  reports it instead of a constant.
- **Records**: run summary naming image digest and revision, `CHANGELOG.md`
  entry, deploy log per `CHANGE_MANAGEMENT.md` §7.
- Aligning `infra-ci.yaml` with the naming contract while the CI rules are open.

**Out**

- Creating the Google Cloud projects and running `terraform apply` — **GGU-29**.
  This spec delivers the pipeline and the identity it needs; the first real
  deploy happens once GGU-29 has applied.
- Web/Flutter hosting and its pipeline — **GGU-26**, **GGU-29**.
- Blue/green or canary traffic splitting beyond the single verify-then-shift
  step; see OD-2.

## 3. API contract

No new HTTP surface. One existing response changes meaning:

| Method & path | Auth | Request | Response | Errors |
|---|---|---|---|---|
| `GET /health` | none | — | `HealthResponse` — `version` is now the **release identifier** | unchanged |

`version` resolves as: `APP_RELEASE` when set and non-blank, otherwise the
packaged `__version__`. The field keeps its type and its OpenAPI description is
updated; no client breaks, because a client that displayed `0.1.0` now displays
`0.1.0+<sha>` or the packaged default in local runs.

## 4. Data model & migration

None. Migrations already run at container start (`RUN_MIGRATIONS=true`), which
is what makes "migrate before traffic shifts" true by construction: the new
revision runs `alembic upgrade head` in its own startup, and traffic only moves
after that revision answers `/readyz`.

## 5. Security notes

- **No long-lived credentials.** Authentication is Workload Identity
  Federation. The provider's attribute condition pins
  `assertion.repository == "somnio-projects/finance-google-a2ui"`, so a token
  minted for any other repository is refused even if the pool name leaks
  (`ACCESS_CONTROL.md` §4). **Production additionally requires
  `assertion.ref == "refs/heads/main"`**: the repository condition alone would
  let any workflow on any branch that can ask for `id-token: write` obtain a
  credential that deploys production. AC-3 is asserted by a test, not by a
  reviewer reading the file.
- **Narrow roles.** The deployer service account holds
  `roles/artifactregistry.writer`, `roles/run.developer` and
  `roles/iam.serviceAccountUser` on the runtime identity only — enough to push
  an image and to create a revision that runs as the backend service account,
  and nothing else. It cannot read secrets, touch the database or change IAM.
- **Production needs a human.** The `production` GitHub Environment carries a
  required reviewer, which is the separation-of-duties control
  `CHANGE_MANAGEMENT.md` §5 asks for: the person who merges is not necessarily
  the person who approves the release.
- **Nothing sensitive is logged.** The workflow prints the image digest, the
  revision name and the release identifier. It never prints the identity token,
  the federated credential or any environment value.
- **Immutable tags.** The digest, not the moving tag, is what gets deployed and
  what the run summary records, so "which code is in production" has one
  unambiguous answer after the fact.

## 6. Acceptance criteria

1. **AC-1** — A push to `develop` builds the image, pushes `:<sha>` and
   `:develop` to Artifact Registry, deploys the staging Cloud Run service with
   no human step, and writes a run summary naming the **image digest** and the
   **revision name**.
2. **AC-2** — A push to `main` reaches the deploy job only after the
   `production` GitHub Environment approval, then deploys production the same
   way.
3. **AC-3** — No service-account key exists in repository secrets:
   authentication is Workload Identity Federation, and the provider only
   accepts tokens whose `repository` claim is this repository.
4. **AC-4** — When any verification fails — the revision never becomes Ready,
   the revision cannot be identified, `/health` does not answer, or it reports
   another release — the script leaves the previously serving revision serving
   and exits non-zero. A failed `gcloud run deploy` never touches traffic at
   all.
5. **AC-5** — The deployed revision answers `/health` 200 with `version` equal
   to the release identifier that was deployed, not a constant.
6. **AC-6** — Every job and step in `backend-cd.yaml` and `infra-ci.yaml`
   follows the naming contract in `.claude/rules/ci-conventions.md`, no
   `- uses:` is left unnamed, and each workflow ends in a `Report · …` summary.

## 7. Test plan

| AC | Unit / local test | CI or manual evidence |
|---|---|---|
| AC-1 | — | `terraform validate`; `actionlint`; first real run needs GGU-29 |
| AC-2 | — | workflow declares `environment: production`; approval is a GitHub setting |
| AC-3 | `infra/scripts/tests/test_wif_conditions.sh` greps the provider for the repository condition and fails if a `google_service_account_key` resource ever appears | `trivy config`; `gitleaks` over full history |
| AC-4 | `infra/scripts/tests/test_deploy_cloud_run.sh` runs the script against a **stub `gcloud`** and a **stub `curl`** on `PATH`, covering all nine paths: happy, not-Ready, wrong release, release-is-a-prefix, `/health` down, deploy failure, unidentifiable revision, explicit rollback, missing variables | same test in `infra-ci` |
| AC-5 | `backend/tests/unit/core/test_release.py` — configured, padded, blank, absent | container run with and without `APP_RELEASE`, `/health` read both times |
| AC-6 | `actionlint` in pre-commit | reading the run summary |

Mutation checks required: **yes, for AC-4.** Removing the rollback call from the
script must turn `test_deploy_cloud_run.sh` red. A deploy script whose rollback
is never exercised is the same false green as an auth test that passes with auth
disabled.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Staging behind the same HTTPS load balancer and Cloud Armor policy as production, or public with IAM-only ingress? | TL | Same topology as production. The value of staging is that it is wrong in the same ways production would be. |
| OD-2 | Canary traffic splitting before full shift? | TL | **No** for the showcase. Deploy without traffic, verify readiness, shift 100 %. A canary needs traffic and metrics we will not have before the demo, and an unobserved canary is theatre. |
| OD-3 | Does `main` auto-tag a release, or is tagging manual? | TL | The workflow creates the tag `v<version>+<sha>` on a successful production deploy, so the tag can only exist for something that actually ran. |
| OD-4 | Is the first real deploy blocked on GGU-29? | TL — **yes, decided** | AC-1, AC-2, AC-4 (live) and AC-5 (live) cannot be demonstrated until the projects exist and Terraform is applied. They are proven here by the script tests and `terraform validate`; the PR says so plainly rather than claiming a deploy that did not happen. |
| OD-5 | How does a GitHub-hosted runner verify a service whose ingress is internal-load-balancer only? | TL — **decided** | It does not reach the `*.run.app` hostnames at all. **Before traffic**, the gate is the revision's own `Ready` condition, which Cloud Run only reports once the startup probe on `/readyz` passes (`infra/run.tf`). **After traffic**, the check goes to `PUBLIC_URL` — the load balancer domain, which is the only address that resolves from outside the VPC — where `/health` is unauthenticated by contract. |
| OD-6 | Who owns the Cloud Run image and traffic fields, Terraform or the pipeline? | TL — **decided** | The pipeline. `infra/run.tf` declares `ignore_changes` on the container image and on `traffic`, so a later `terraform apply` cannot re-point traffic at a revision the pipeline had just rolled back from. Terraform still owns the shape: identity, scaling, networking, secrets and probes. |

## 9. Rollout & observability

- **Order:** merge this → GGU-29 creates the projects and applies Terraform
  (which now also creates the registry, the pool and the deployer identity) →
  add the three repository variables → the next merge to `develop` deploys.
- **Repository variables** (not secrets — none of them is confidential).
  Each environment has its own pool, provider and deployer identity, so all of
  them except the region are suffixed: `GCP_REGION`,
  `GCP_PROJECT_ID_{STAGING,PRODUCTION}`, `GCP_WIF_PROVIDER_{STAGING,PRODUCTION}`,
  `GCP_DEPLOYER_SA_{STAGING,PRODUCTION}`, `PUBLIC_URL_{STAGING,PRODUCTION}`.
  Terraform outputs the provider, the deployer and the registry; the workflow's
  first job resolves the pair for the branch and **fails with a named variable**
  if one is missing, rather than authenticating as the wrong environment.
- **Observability:** each run writes a summary table (environment, digest,
  revision, release, readiness result). The deploy log required by
  `CHANGE_MANAGEMENT.md` §7 is the run itself, linked from `CHANGELOG.md`.
- **Rollback in anger:** the same script is runnable by hand with
  `ROLLBACK_TO=<revision>`; the procedure is written in `infra/README.md` so it
  does not live only in a workflow file.
