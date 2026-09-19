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

Prerequisites: a versioned GCS state bucket; the Artifact Registry repository
`finance-a2ui` with the backend image pushed by CI; a Firebase/Identity project
for `auth_issuer`; DNS control of `domain` (point an A record at `api_ip`).
After the first apply, populate the `secrets_to_populate` secrets in the
console (never via Terraform), then run the backup/restore drill against the
new instance (`docs/compliance/RESTORE_DRILL_LOG.md`).

## Checks in CI

`.github/workflows/infra-ci.yaml`: `terraform fmt -check`, `init -backend=false`,
`validate`, and `trivy config` (misconfiguration rules incl. the tfsec set)
failing on HIGH/CRITICAL.
