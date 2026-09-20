# Disaster Recovery Plan

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC7.5, A1.2, A1.3 · ISO/IEC 27001 A.5.30, A.8.13, A.8.14 |

Targets: **RPO 24 h (1 h with Cloud SQL PITR) · RTO 4 h** — from
[BUSINESS_CONTINUITY_PLAN.md](BUSINESS_CONTINUITY_PLAN.md).

## 1. Scenarios and procedures

### S1 — Database lost or corrupted (volume loss, bad migration, accidental drop)

1. IC declares SEV-1; stop writes (scale backend to 0 / `docker compose stop backend`).
2. Take a forensic dump of what remains (`pg_dump -Fc`) → incident evidence folder.
3. Provision an empty database (compose: `docker compose up -d db` on a fresh volume; Cloud SQL: restore instance from the latest automated backup or PITR to the chosen timestamp).
4. Restore the latest good backup: `pg_restore --no-owner --exit-on-error -d finance <dump>` (see [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) §3).
5. `alembic upgrade head` — brings the schema to the current revision if the dump predates a migration.
6. Verify: `alembic current` = head, row counts vs. backup manifest, `/readyz` ready, one authenticated `GET /v1/me` and `GET /v1/me/audit-events`.
7. Restart writes; announce recovery; postmortem.

### S2 — Backend instance / host lost

1. Rebuild from source: `docker compose up --build -d backend` (or deploy the last known-good image tag to Cloud Run).
2. Entry point runs migrations idempotently; verify `/health`, `/readyz`.
3. No data step needed — the service is stateless.

### S3 — Region unavailable (production)

1. Restore the Cloud SQL backup into a new instance in the fallback region (`southamerica-west1` if primary `us-central1` is down — to be confirmed in IaC).
2. Deploy the same image to Cloud Run in that region with the restored `DATABASE_URL` secret.
3. Repoint DNS / the client base URL; run the S1 verification list.

### S4 — Signing secret or model key compromised

Covered by the incident response plan (rotate → redeploy → invalidate); DR
adds only: confirm backups do not contain secrets (they never do — secrets
live in env/Secret Manager, not in the database).

### S5 — GitHub / CI unavailable

Local clone is the source of truth. `cd backend && make gate` reproduces CI
verbatim; a manual `docker build` + deploy is allowed under
[EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md) with post-hoc review when GitHub
returns.

## 2. Recovery order

1. Database (S1) → 2. Backend (S2) → 3. Verification → 4. Communications.

## 3. Roles and access needed

IC and technical lead need: Docker host / GCP project access, Secret Manager
read for `DATABASE_URL`, backup bucket read. Access is verified in the
quarterly access review ([ACCESS_CONTROL.md](ACCESS_CONTROL.md)).

## 4. Redundancy today vs. target

The production column is implemented in [`infra/`](../../infra/README.md) (Terraform, validated, apply pending GGU-29).

| Layer | Demo (compose) | Dev (`infra/`, `environment = "dev"`) | Production target (`infra/`, GGU-29) |
|---|---|---|---|
| Database | single container, daily dump | Cloud SQL **zonal**, daily backups, **no PITR** | Cloud SQL HA (regional standby), automated backups + PITR |
| Backend | single container, health-checked | Cloud Run **scale-to-zero**, no uptime check | Cloud Run ≥ 1 min instance, multi-zone, `/readyz` uptime check |
| Secrets | `.env` per solution (never committed) | Secret Manager, versioned, 90-day rotation | Secret Manager, versioned, 90-day rotation |
| Logs | container stdout (JSON) | Cloud Logging, **30-day** retention | Cloud Logging, 90-day retention |

**Dev has no disaster-recovery commitment.** Losing it is not an incident: the
recovery procedure is `terraform apply` followed by a re-seed, and the data is
synthetic. It is listed here so nobody reads the production column and assumes
it describes every deployed environment.

## 5. Drills

| Drill | Cadence | Last | Result |
|---|---|---|---|
| Restore into scratch database and verify (S1 steps 3–6 without stopping the service) | quarterly | 2026-09-19 | pass — [RESTORE_DRILL_LOG.md](RESTORE_DRILL_LOG.md) |
| Full S1 on a fresh volume (stop service, restore, migrate, verify) | annually | planned 2026-Q4 | — |
| S3 regional restore | annually once IaC exists | — | — |
