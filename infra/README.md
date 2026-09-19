# infra/ — Google Cloud infrastructure as code (ADR-F)

Terraform for one environment per GCP project (`staging`, `production`). It
implements the production topology committed in
[`docs/compliance/CLOUD_SERVICES.md`](../docs/compliance/CLOUD_SERVICES.md) §3:

| File | What | Controls |
|---|---|---|
| `network.tf` | VPC, connector subnet with flow logs, private services access, Serverless VPC connector, deny-all ingress | CC6.6 · A.8.20, A.8.22 |
| `database.tf` | Cloud SQL PostgreSQL 16 — private IP only, TLS required, **regional HA**, daily backups + **PITR**, 30 retained backups, insights, connection logging, deletion protection | A1.2 · A.8.13, A.8.14, A.8.24 |
| `secrets.tf` | Secret Manager: one secret per setting, regional replication, **90-day rotation** events on Pub/Sub; `DATABASE_URL` and `AUTH_JWT_SECRET` generated; `SENTRY_DSN`/`GEMINI_API_KEY` populated out of band | CC6.1 · A.5.17, A.8.24 |
| `iam.tf` | Runtime service account with `cloudsql.client`, log/metric writers and **per-secret** accessor; scheduler account limited to running the purge job | CC6.1, CC6.3 · A.5.15, A.8.2 |
| `run.tf` | Cloud Run v2 service (LB-only ingress, private egress, probes on `/readyz` and `/healthz`, secrets as env), Cloud Run **job** (`python -m app.jobs.purge_audit`) + Cloud Scheduler for the monthly `audit_events` purge | CC7.2, A1.2 · A.8.9, A.8.16 |
| `edge.tf` | Global external HTTPS LB, managed certificate, TLS 1.2+ policy, **Cloud Armor** (OWASP SQLi/XSS/RCE/LFI, per-IP throttling, adaptive L7 DDoS), HTTP→HTTPS redirect, edge access logs | CC6.6 · A.8.21, A.8.23 |
| `delivery.tf` | Artifact Registry repository (digest-addressed images, keep 20, drop untagged after 30 days), the **Workload Identity** pool and provider pinned to this GitHub repository, and the **deployer** service account (`artifactregistry.writer`, `run.developer`, `serviceAccountUser` on the runtime identity only). **No service-account key exists anywhere in this directory** | CC6.1, CC6.3, CC8.1 · A.5.15, A.8.4, A.8.32 |
| `observability.tf` | `_Default` log bucket **90-day retention**, data-access **audit logs** for Cloud SQL / Secret Manager / Cloud Run, uptime check on `/readyz`, alerts (readiness, 5xx spike, auth-failure spike) to the on-call channel | CC7.2 · A.8.15, A.8.16 |

## Status

**Committed and validated (`terraform validate`, `trivy config`), not yet
applied** — the GCP projects are created with the deploy epic **GGU-29**. Until
then the only running topology is the local `docker-compose.yml`, and risk R-11
in `docs/compliance/RISK_ASSESSMENT.md` stays retained.

## Apply (GGU-29 runbook)

```bash
cd infra
terraform init -backend-config="bucket=<state-bucket>" -backend-config="prefix=finance-a2ui/<env>"
terraform plan  -var-file=environments/<env>.tfvars
terraform apply -var-file=environments/<env>.tfvars
```

Prerequisites: a versioned GCS state bucket; a Firebase/Identity project for
`auth_issuer`; DNS control of `domain` (point an A record at `api_ip`). The
Artifact Registry repository is created by this configuration (`delivery.tf`),
so the first apply runs with a placeholder `backend_image`; the pipeline
replaces it on the first deploy.

After the first apply, populate the `secrets_to_populate` secrets in the
console (never via Terraform), run the backup/restore drill against the new
instance (`docs/compliance/RESTORE_DRILL_LOG.md`), and set the repository
variables the pipeline reads, from the Terraform outputs:

| Repository variable | Terraform output |
|---|---|
| `GCP_WIF_PROVIDER` | `wif_provider` |
| `GCP_DEPLOYER_SA` | `deployer_service_account` |
| `GCP_PROJECT_ID_STAGING` / `GCP_PROJECT_ID_PRODUCTION` | the project of each environment |
| `GCP_REGION` | `var.region` |

They are **variables, not secrets** — none of them is confidential, and the
security of the pipeline is the provider's repository condition, not the
obscurity of these names.

## Deploy and roll back (GGU-48)

Deploys happen through `.github/workflows/backend-cd.yaml`: merge to `develop`
releases staging with no human step, merge to `main` releases production after
the `production` environment's required reviewer approves.

The sequence lives in `infra/scripts/deploy_cloud_run.sh` — create the revision
with **no traffic** (its startup runs `alembic upgrade head`), probe `/readyz`
on that revision, shift 100 % of traffic, verify `/healthz` reports the released
identifier, and **restore the previous revision** if any of that fails.

To roll back by hand, without waiting for a pipeline:

```bash
SERVICE=finance-a2ui-production-api REGION=us-central1 PROJECT=<project> \
ROLLBACK_TO=<last-good-revision> ./infra/scripts/deploy_cloud_run.sh
```

or re-run `backend-cd` from the Actions tab with `rollback_to` set. List the
revisions with `gcloud run revisions list --service=<service> --region=<region>`.

The script's behaviour — including the rollback — is covered by
`infra/scripts/tests/test_deploy_cloud_run.sh`, which runs it against a stub
`gcloud`. Change the script, run that test.

## Checks in CI

`.github/workflows/infra-ci.yaml` runs two jobs:

- **Infrastructure** — `terraform fmt -check`, `init -backend=false`, `validate`,
  and `trivy config` (misconfiguration rules incl. the tfsec set) failing on
  HIGH/CRITICAL.
- **Delivery** — `shellcheck`, the deploy-script behaviour tests (including the
  rollback), and `test_wif_conditions.sh`, which fails the build if a
  `google_service_account_key` resource ever appears here or if the identity
  provider stops being pinned to this repository.

Both also run in `pre-commit`, so they cost nothing on a laptop.
