# 0001 — A dev environment sized for a proof of concept

- **Area:** infrastructure (`infra/`, `.github/workflows/backend-c[di].yaml`)
- **Status:** Draft
- **Ticket:** [GGU-29](https://somniosoftware.atlassian.net/browse/GGU-29) · **Related:** [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md), [ADR-G](../../docs/adr/ADR-G-secret-handling.md), [spec 0007](../backend/0007-cd-pipeline.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

## 1. Problem

`infra/` has never been applied. It describes one topology — production — and
`terraform apply` against it today would stand up roughly **US$150/month of
idle infrastructure** before a single request arrives: a Cloud SQL instance
with a synchronous standby in a second zone, point-in-time recovery and 30
retained backups; a global HTTPS load balancer with a reserved anycast IP, a
managed certificate and a Cloud Armor policy; a Serverless VPC Access
connector whose floor is two always-on VMs; and a Cloud Run service pinned to
`min-instances = 1`.

None of that is wrong for production. All of it is wrong for what the TL
actually asked for: a **proof of concept**, "whatever fits best and is
simplest", on a project where he has said plainly he does not want to spend
money. Two of those items cannot even be applied as written — the managed
certificate needs a domain we do not own, and `deletion_protection = true`
means the POC could not be torn down without editing Terraform first.

The `environment` variable also refuses the word: it validates against
`["staging", "production"]`, so there is no name to apply this under.

## 2. Scope

**In**

- `environment = "dev"` accepted, and **derived** into a cheap shape: one
  `local.ephemeral`, computed from the environment name, switches every
  expensive control. Not a set of booleans a caller must remember to align.
- Cloud SQL in dev: zonal, smallest tier, no PITR, 2 retained backups, no
  deletion protection.
- `edge.tf` **entirely absent** in dev; Cloud Run's own `run.app` URL is the
  endpoint, which is why dev's ingress is open.
- No VPC connector in dev — Cloud Run reaches the private database through
  direct VPC egress instead.
- `domain` optional, and validated **against** the environment in both
  directions.
- `environments/dev.tfvars`, and a `public_url` output that reports where the
  API actually answers.
- `backend-cd`: `develop` releases **dev** (not staging), and only after the
  full ship gate has passed on that commit.
- The honesty half: which controls dev does **not** have, recorded here and in
  `docs/compliance/`, and a gate test that keeps both true.

**Out**

- Applying any of it. Terraform is validated, never applied, in this work —
  the state bucket and the first apply are the TL's call (§9).
- Staging. It is replaced by dev as a deploy target, not deleted: the
  `staging.tfvars` file and every staging behaviour in the Terraform are
  untouched, so re-adding it is a workflow change and nothing else.
- Any change to production's shape. Verified, not asserted (AC-1).
- A separate GCP project for dev (OD-1).

## 3. What each environment creates

`local.ephemeral` in `infra/main.tf` is the only input to this table.

| | dev | staging / production |
|---|---|---|
| Cloud SQL availability | `ZONAL` | `REGIONAL` (synchronous standby) |
| Cloud SQL tier | `db-f1-micro` | `db-custom-1-3840` |
| Point-in-time recovery | off | on, 7 days of write-ahead logs |
| Retained backups | 2 | 30 |
| `deletion_protection` (DB) | **off** | on |
| Disk | 10 GB `PD_HDD` | 10 GB `PD_SSD` |
| Private IP only · TLS-only · connection logging | **same** | same |
| Load balancer, anycast IP, managed cert, TLS policy | **none** | all |
| Cloud Armor (OWASP WAF, per-IP throttle, adaptive DDoS) | **none** | yes |
| HTTP→HTTPS redirect | none | yes |
| Cloud Run ingress | `ALL` (run.app is the endpoint) | internal + load balancer |
| Cloud Run min / max instances | 0 / 2 | 1 / 4 (staging 0 / 2) |
| VPC egress path | direct VPC egress | Serverless VPC connector (2 VMs) |
| Egress scope | `PRIVATE_RANGES_ONLY` | **same** |
| Deny-all ingress firewall, flow logs, private services access | **same** | same |
| Secret Manager, per-secret IAM, 90-day rotation | **same** | same |
| Workload Identity, no service-account key | **same** | same |
| Uptime check on `/readyz` + readiness alert | **none** | yes |
| 5xx and auth-failure alerts | **same** | same |
| Data-access audit logs | **same** | same |
| Log retention | 30 days | 90 days |
| Audit-trail purge job (400-day retention) | **same** | same |
| Images kept in Artifact Registry | 5 | 20 |

The pattern is deliberate and is the argument for this shape: **dev gives up
durability, redundancy and the paid edge. It does not give up the controls
that cost nothing** — the database still has no public IP, still refuses
unencrypted connections, still sits behind a deny-all firewall with egress
restricted to private ranges; secrets still come from Secret Manager with
per-secret IAM; the pipeline still holds no long-lived key.

## 4. Cost

Shape and drivers, not a quote. Rates move, and the only figure anyone should
act on is the project's own billing report after a week.

| Line | dev, idle | staging/production, idle | Why |
|---|---|---|---|
| Cloud SQL instance | **single shared-core, cheapest tier** | ~4× that for `db-custom-1-3840`, then **doubled** by the regional standby | HA is a second instance running continuously |
| Backups / PITR | 2 backups of a near-empty 10 GB disk | 30 backups + continuous WAL retention | storage, and WAL grows with writes |
| Load balancer + IP | **nothing — does not exist** | fixed monthly forwarding-rule + reserved-IP charge, **whether or not a request arrives** | the LB is provisioned capacity, not usage |
| Cloud Armor | **nothing — does not exist** | per-policy + per-rule monthly charge | same |
| VPC connector | **nothing — direct VPC egress** | 2 × e2-micro billed hourly, minimum | the connector is a managed instance group |
| Cloud Run | **nothing at min-instances 0** | one instance always warm | idle instances bill CPU/memory |
| Logging | 30 days, inside the free allowance at POC volume | 90 days | retention beyond 30 days is billed storage |

**The shape:** production's idle cost is dominated by things that bill for
existing — the standby, the load balancer, the Cloud Armor policy, the
connector VMs, the warm instance. Dev has none of them, so **dev's idle cost is
approximately the cheapest Cloud SQL instance and nothing else**, and its
variable cost is whatever the demo actually uses. The brief's ~US$150/month
estimate for the production shape is consistent with that breakdown; we have
not independently priced it and this spec does not claim a dev figure, because
the honest one is "close to the price of one shared-core Postgres instance,
confirm it on the first billing report".

**The lever that matters most is `terraform destroy`.** Dev turns
`deletion_protection` off precisely so the POC can be deleted the day it stops
being useful. That is the difference between a small monthly bill and a
permanent one.

## 5. What dev gives up — say it plainly

Dev is **not** production with fewer replicas. It is a smaller control set, and
these are the controls it does not have:

| Control | Production | Dev | What still stands in dev |
|---|---|---|---|
| WAF (OWASP SQLi/XSS/RCE/LFI) | Cloud Armor | **none** | the API takes no SQL, no HTML and no file paths from input; parameterised queries and pydantic validation at every boundary |
| Edge rate limit | Cloud Armor, per IP | **none** | the application's own per-principal limiter (ADR-G D-7) is unchanged and is the control the threat model actually rests on |
| Adaptive L7 DDoS | Cloud Armor | **none** | Cloud Run's own scaling ceiling (`max-instances = 2`) bounds the blast radius to a small bill, not an outage of something that matters |
| TLS policy of our choosing | `MODERN`, TLS 1.2+ | Google's `run.app` defaults | still TLS-only, still a Google-managed certificate; we simply do not pick the profile |
| Edge access log | LB logs, sampled 1.0 | **none** | Cloud Run request logs still record every request |
| Uptime check + readiness alert | yes | **none** | the 5xx and auth-failure alerts still page; the deploy itself verifies `/health` and rolls back |
| Regional HA | synchronous standby | **none** | a zone failure loses dev until it is re-applied. Acceptable: the data is synthetic and the environment is disposable |
| Point-in-time recovery | to the minute | **none** | 2 daily backups; RPO is up to 24 h |
| Backup retention | 30 | 2 | — |
| Deletion protection | on | **off** | this is intentional, not an oversight (§4) |
| Log retention | 90 days | 30 days | — |

What is **unchanged** and is the reason "no Cloud Armor" is not "no
protection": bearer-token authentication on every non-health route, the
per-principal rate limiter, RFC 9457 errors that leak no internals, security
headers, audit events, the non-root read-only container, no public database
IP, TLS-only database connections, Secret Manager with per-secret IAM, and a
keyless delivery pipeline.

**Dev holds synthetic data only.** Every statement above depends on that. If
real or client data is ever put in dev, this spec is void and the environment
must be re-sized first.

## 6. Acceptance criteria

1. **AC-1** — Applying `staging.tfvars` or `production.tfvars` produces exactly
   the configuration it produced before this change: `REGIONAL`,
   `db-custom-1-3840`, PITR on, 30 backups, deletion protection on, the full
   edge, LB-only ingress, 1/4 (staging 0/2) instances, 90-day logs.
2. **AC-2** — `environment = "dev"` is accepted; any other value than
   dev/staging/production is refused by name.
3. **AC-3** — In dev, Cloud SQL is zonal, on the smallest tier, with PITR off,
   2 retained backups and `deletion_protection = false`.
4. **AC-4** — In dev, **no** resource declared in `edge.tf` is created, and no
   VPC Access connector is created.
5. **AC-5** — `domain` is not required for dev, is required for staging and
   production, and setting it on dev is refused rather than ignored.
6. **AC-6** — In dev the API is reachable at Cloud Run's own URL, which the
   `public_url` output reports from the service's real address; the deploy
   script's post-shift `/health` probe therefore works unchanged in dev.
7. **AC-7** — Every control in §5 that dev does not have is stated in the
   compliance corpus, in the document that otherwise asserts it.
8. **AC-8** — A merge to `develop` deploys to **dev**, and `publish`/`deploy`
   cannot run unless the full ship gate succeeded **on that commit**.
9. **AC-9** — A merge to `main` still deploys production behind the
   `production` Environment's required reviewer, unchanged.
10. **AC-10** — A missing per-environment repository variable fails the run
    naming the variable exactly as a human must create it (`GCP_PROJECT_ID_DEV`,
    not `GCP_PROJECT_ID`).
11. **AC-11** — `terraform fmt -recursive -check` and `terraform validate` pass.

## 7. Test plan

There is no pytest here; the checks are the infra gate
(`.claude/ship-gate.json` → `infra.*`) and `terraform` itself.

| AC | Proven by |
|---|---|
| AC-1 | `terraform console` over the posture locals with each tfvars file, compared against the pre-change values — recorded in the PR body. The staging/production columns came back identical. |
| AC-2, AC-5 | `terraform console -var 'environment=qa'`, `-var 'domain=…'` on dev and `-var 'domain='` on production each rejected by the variable validations, with the intended message |
| AC-3, AC-4 | `infra/scripts/tests/test_dev_environment.sh` — every switched value is asserted to be *derived*, and the edge count is compared against the number of resources in `edge.tf` so a newly added edge resource without a `count` fails |
| AC-6 | `infra/scripts/tests/test_deploy_cloud_run.sh` (unchanged, still 36 assertions incl. the rollback) + the `public_url` output assertion in `test_dev_environment.sh` |
| AC-7 | review against `docs/compliance/` (§8 lists every document touched) |
| AC-8, AC-9, AC-10 | `test_dev_environment.sh` asserts the `needs: [ci, …]` edges, `workflow_call`, `environment=dev` for non-main, `environment=production` for main, and the Environment binding |
| AC-11 | `infra-ci.yaml` → `terraform fmt -check -recursive`, `init -backend=false`, `validate`, `trivy config` |

**Mutation check — required, and performed.** Two deliberate regressions were
introduced and the suite was re-run:

| Mutation | Result |
|---|---|
| `availability_type = local.db_availability` → `"REGIONAL"` | `FAIL  availability_type is not hard-coded` |
| `deploy: needs: [ci, settings, publish]` → `[settings, publish]` | `FAIL  the deploy waits for the gate` |

Both were restored and the suite returned 31/31. A gate assertion that cannot
go red is not a gate assertion.

## 8. Compliance record

Each row is a control that is now conditional. The document that asserts the
control says so, in place — the corpus must not keep claiming a control an
environment does not have.

| Document | What was added |
|---|---|
| `CHANGE_MANAGEMENT.md` §2 | `dev` row in the environment table; `staging` marked not provisioned; promotion order and the `develop → dev` deploy line |
| `CLOUD_SERVICES.md` §3–§5 | a per-environment topology column; Cloud Armor marked production-only; dev's log retention; no uptime check in dev |
| `BACKUP_AND_RECOVERY.md` §2 | dev's backup posture (2 backups, no PITR, no HA) and its RPO |
| `DISASTER_RECOVERY_PLAN.md` | dev added to the layer table as "re-apply, do not restore" |
| `BUSINESS_CONTINUITY_PLAN.md` §5 | the production commitments apply to production, not to dev |
| `DATA_RETENTION.md` | dev's 30-day application-log retention |
| `DATA_RESIDENCY_AND_TENANCY.md` | dev's TLS termination is Cloud Run's, not an LB we configure |
| `RISK_ASSESSMENT.md` | R-16: dev runs without WAF/HA/PITR — accepted, bounded by "synthetic data only" |
| `isms/STATEMENT_OF_APPLICABILITY.md` | A.8.23 and A.8.31 reworded to name where each control applies |

## 9. Rollout

1. **A human creates the state bucket.** Not this spec's work and not the
   agent's: a versioned GCS bucket is the first billable object and the TL owns
   that decision.
2. `terraform init -backend-config=…` then `plan -var-file=environments/dev.tfvars`.
   **Read the plan before applying it** — this configuration has never been
   applied in any environment, and the plan is the first real feedback anyone
   gets on it. In particular confirm that Cloud SQL accepts `db-f1-micro` for
   `POSTGRES_16` (OD-2) and that direct VPC egress accepts the `/26` (OD-3).
3. `apply`. Then populate the `secrets_to_populate` secrets in the console —
   `GEMINI_API_KEY` and `SENTRY_DSN`, by hand, never through Terraform
   (ADR-G D-2). **No value for either is invented, committed or guessed
   anywhere in this change.**
4. Read the outputs and create the repository **variables** (not secrets, none
   of them is confidential): `GCP_PROJECT_ID_DEV`, `GCP_WIF_PROVIDER_DEV`
   (← `wif_provider`), `GCP_DEPLOYER_SA_DEV` (← `deployer_service_account`),
   `PUBLIC_URL_DEV` (← `public_url`), `GCP_REGION`. Until they exist the
   pipeline fails on the `settings` job naming the missing one (AC-10).
5. A `dev` GitHub Environment is created on first use and needs no reviewer.
   Do not add one to `production`'s — it already has the required reviewer and
   that is the separation-of-duties control for release.

## 10. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Does dev get its own GCP project, or share `finance-a2ui`? `CHANGE_MANAGEMENT.md` §2 says one project per environment, and sharing would put a dev deployer identity in the same project as a future production. | TL | `dev.tfvars` names `finance-a2ui` — the only project with billing today, and nothing else is deployed in it. Production must get its own project **before** it is first applied; every resource name is already environment-suffixed, so no code changes either way. |
| OD-2 | ~~Is `db-f1-micro` accepted for `POSTGRES_16`?~~ **Resolved at the first apply, and the guessed fallback was wrong.** | — | The tier was never the problem; the **edition** was. `edition` was not set, the API does *not* infer it from the tier, and it defaulted to `ENTERPRISE_PLUS`, which accepts only `db-perf-optimized-N-*`: `Invalid Tier (db-f1-micro) for (ENTERPRISE_PLUS) Edition`. `db-g1-small` would have failed identically, so the recorded fallback would not have helped. `edition` is now pinned to `ENTERPRISE` in `main.tf` for every environment — see §11. `terraform plan` accepted the invalid combination, which is the general lesson: plan validates the *schema*, not the API's own compatibility rules. |
| OD-3 | ~~Is a `/26` right for direct VPC egress?~~ **Resolved: it applied and the service runs.** | — | `/26` against a 2-instance ceiling. The service reached Cloud SQL over the private IP on the first try (`/readyz` → `{"status":"ready","dependencies":[{"name":"database","ready":true}]}`). |
| OD-4 | Do staging and production need the `allUsers` → `run.invoker` binding that dev now has? A serverless NEG behind the HTTPS load balancer normally does, with `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` as the network control rather than IAM. | TL at their first apply | Almost certainly yes, but **unverified** — neither environment has ever been applied, and guessing would either break the LB path or open an API. `iam.tf`'s binding is `count = local.ephemeral ? 1 : 0` so dev is fixed without asserting anything about the others. |
| OD-4 | Does staging come back? It has no project and is now nobody's deploy target. | TL | It stays as tfvars and Terraform behaviour, deployed by nothing. If it returns, `backend-cd`'s `settings` job grows a third branch; the Terraform already supports it. |
| OD-5 | Is the `dev` GitHub Environment left unprotected? | TL | Yes — an unattended deploy from `develop` is the point. |

## 10b. What the first real apply found

Five defects that no check in this repository could have caught, because every
one of them lives in the gap between two things that were each internally
consistent. `terraform validate` cannot see Python; `make gate` cannot see
Terraform; and `terraform plan` does not ask the API whether a combination it
accepts syntactically is one the API will honour.

| # | Defect | Why nothing caught it | Fixed by |
|---|---|---|---|
| 1 | `edition` unset defaulted to `ENTERPRISE_PLUS`, which rejects every shared-core tier | `plan` validates the schema, not tier/edition compatibility | `local.db_edition = "ENTERPRISE"`, pinned (`main.tf`) |
| 2 | `sqladmin.googleapis.com` does not accept a service-level audit config | The name is real and the API is real — it is the wrong one of two | `cloudsql.googleapis.com` (`observability.tf`) |
| 3 | Secret Manager's service agent did not exist, then existed but was not yet visible to IAM | An identity created and used inside one apply | `google_project_service_identity` + a 30 s propagation wait (`secrets.tf`) |
| 4 | **`ENVIRONMENT=dev` was not a value the backend would accept** — the container would have died at startup on a `ValidationError` | `variables.tf` and `config.py` each held half the answer and nothing read both | `dev` added to `Environment`; the two lists are now compared by `test_dev_environment.sh` |
| 5 | A mounted-but-empty optional secret arrives as `""`, not as absent, so `sentry_sdk.init(dsn="")` and a keyless Gemini client would have been constructed | The factories branch on `is None` and unit tests never mount an empty secret | `OptionalCredentialParsing` collapses blank to `None` (`config_parsing.py`) |

Defects 4 and 5 are the interesting pair: both are **a deployment handing the
application something no test ever hands it**. The lesson is in
`.claude/rules/backend/testing.md` already — *a property that spans two
declarations gets a test comparing them* — and #4 now has exactly that test.

**6 — Google's edge intercepts the exact path `/healthz` on `*.run.app`.**
The liveness endpoint was never reached: the pipeline's post-shift
verification probed it ten times and got Google's own HTML 404 each time,
against a service that was serving normally. Proven rather than assumed, from
two independent networks (a laptop and a GitHub Actions runner) and against
two controls:

| path | response | reached the container? |
|---|---|---|
| `/HEALTHZ` | `{"detail":"Not Found"}` | yes, in the request log |
| `/nonexistent-path` | `{"detail":"Not Found"}` | yes, in the request log |
| `/healthz` | Google's HTML 404 | **never logged** |

`/health`, `/livez`, `/_health`, `/healthcheck`, `/status` and `/alivez` were
all probed before choosing — every one reaches the app, so the interception is
specific to `/healthz` and the replacement was picked on evidence, not
convention. The path is now `/health` everywhere; behaviour, DTO and contract
are unchanged. Historical records (`CHANGELOG.md`, the harness log, archived
`docs/specs/GGU-*`) keep saying `/healthz` because that is what was true when
they were written.

Note this would *not* have shown up behind the load balancer, which is our own
frontend — it is specific to the run.app domain, which is exactly what dev
uses because it has no LB. An endpoint that works in some environments and not
others is worse than one path that works everywhere, which is why this is a
rename rather than a dev-only workaround.

A seventh is **not** fixed here and is the one thing standing between this
environment and AC-1: the service had no `run.invoker` binding at all, so it
answers 403 to any caller without a Google identity. The Terraform is written
(`iam.tf`, dev-only) and planned; applying it is a deliberate exposure decision
and is the TL's to make. See OD-4.

## 11. Divergences found in the existing Terraform

Noted while working, **not fixed here** — each is someone's call, not a
drive-by:

- **ADR-F D-4 says Cloud Run runs `min-instances=1, max-instances=1`** because
  session state is in process memory and a scaled-out follow-up turn would hit
  an instance with no session. The committed Terraform has always used 1/4
  (production) and 0/2 (staging), and dev now derives 0/2. The ADR looks
  **superseded in fact** — sessions are persisted in PostgreSQL
  (`alembic/versions/20260919_0004_sessions.py`, `session_repository.py`) — but
  it is still marked Accepted and nothing records the supersession. Someone
  should either amend ADR-F or write the ADR that replaces it; until then the
  repo asserts a constraint the code does not honour.
- `infra/README.md` and `docs/diagrams/08-infrastructure.md` both described
  "one environment per GCP project (`staging`, `production`)" as settled. Both
  are updated here; the underlying question is OD-1.
- `specs/README.md`'s index has **duplicate rows** (0003, 0006 and 0013 each
  appear twice). Left alone apart from adding the `infra/` area — fixing the
  index is a separate, trivially reviewable change.
