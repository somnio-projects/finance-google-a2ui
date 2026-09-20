# Backup and Recovery

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 A1.2, A1.3, C1.1 · ISO/IEC 27001 A.8.13 |

## 1. What is backed up

Only PostgreSQL holds state: `audit_events`, `feature_flags`,
`alembic_version`. Source, configuration and the harness are in git
(distributed by nature). Secrets are **never** in backups — they live in each
solution's `.env` / Secret Manager.

## 2. Schedule, retention, encryption

| Environment | Mechanism | Frequency | Retention | Encryption |
|---|---|---|---|---|
| Local / demo (compose) | `pg_dump -Fc` from the `db` container (§3) | daily while the demo stack is in use, and **before every migration deploy** | 14 days locally, in the operator's encrypted home directory (FileVault); never committed | at rest by the host disk encryption |
| **Dev** (Cloud SQL — `infra/database.tf` with `environment = "dev"`, apply with GGU-29) | automated daily backups only — **no point-in-time recovery, no regional standby** | daily | **2 backups** | Google-managed AES-256 at rest |
| Production / staging (Cloud SQL — `infra/database.tf`, apply with GGU-29) | automated daily backups + point-in-time recovery (WAL) | daily + continuous WAL | 30 days | Google-managed AES-256 at rest (CMEK optional, decision recorded in DATA_RESIDENCY_AND_TENANCY) |

**Dev is deliberately outside the recovery commitments above**
([specs/infra/0001-dev-environment.md](../../specs/infra/0001-dev-environment.md)
§5). Its RPO is **up to 24 hours** and it has no RTO commitment at all: it is a
throwaway proof of concept holding **synthetic data only**, and the recovery
procedure for it is to re-apply Terraform and re-seed, not to restore. Deletion
protection is off on that instance on purpose, so it can be destroyed the day
it stops being useful. If real or client data is ever placed in dev, this row
and that spec are void and the environment must be re-sized first.

Backups contain Confidential data (`audit_events`) and are handled per
[DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md): restricted access (IC,
TL backend), no copies on unencrypted media, deletion at the end of
retention.

## 3. Runbook — dump and restore (compose)

```bash
# backup (custom format, compressed)
docker exec finance-a2ui-db-1 pg_dump -U app -d finance -Fc > finance-$(date +%Y%m%d).dump

# restore into a scratch database (drill) or into `finance` (recovery)
docker exec finance-a2ui-db-1 psql -U app -d postgres -c "create database finance_restore owner app"
docker exec -i finance-a2ui-db-1 pg_restore -U app -d finance_restore --no-owner --exit-on-error < finance-YYYYMMDD.dump

# verify
docker exec finance-a2ui-db-1 psql -U app -d finance_restore -c \
  "select (select count(*) from audit_events) audit, (select count(*) from feature_flags) flags, (select version_num from alembic_version) rev"
cd backend && DATABASE_URL=postgresql+asyncpg://app:app@127.0.0.1:5432/finance_restore uv run alembic current
```

Recovery into the live database: stop the backend, restore into `finance`
(drop and recreate first), `alembic upgrade head`, start the backend, check
`/readyz` and one authenticated request — the full procedure is scenario S1
in [DISASTER_RECOVERY_PLAN.md](DISASTER_RECOVERY_PLAN.md).

## 4. Verification

- Every backup is verified by size > 0 and a `pg_restore --list` of the archive.
- **Quarterly restore drill**: restore the latest dump into a scratch database, compare row counts and the Alembic revision with the source, drop the scratch copy. Recorded in [RESTORE_DRILL_LOG.md](RESTORE_DRILL_LOG.md).
- Production: Cloud SQL backup success is alerted through Cloud Monitoring (CLOUD_SERVICES §5).

## 5. Ownership

The TL backend owns backups and drills; the IC may delegate the restore to
the technical lead during an incident. Failures to back up or to pass a drill
are nonconformities ([isms/NONCONFORMITY_LOG.md](isms/NONCONFORMITY_LOG.md)).
