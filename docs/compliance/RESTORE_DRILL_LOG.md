# Restore Drill Log

Evidence for SOC 2 A1.2/A1.3 and ISO/IEC 27001 A.8.13/A.8.14. One row per
executed drill; the procedure is [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) §3–4
and scenario S1 of the [DISASTER_RECOVERY_PLAN.md](DISASTER_RECOVERY_PLAN.md).
Cadence: quarterly (next due **2026-12-19**). A failed or skipped drill is a
nonconformity.

| # | Date (UTC) | Environment | Source | Procedure | Verification | Duration | Result | Operator |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-19 11:04:34 → 11:04:35 | local compose stack (`finance-a2ui-db-1`, PostgreSQL 16.15 aarch64) | live `finance` database at Alembic revision `0002` | `pg_dump -Fc` (4 521 bytes, sha256 `870944fb4e943599…`) → `create database finance_restore_drill` → `pg_restore --no-owner --exit-on-error` → compare → `drop database finance_restore_drill` | row counts `audit_events=3`, `feature_flags=1`, `alembic_version=0002` identical on source and restored copy | ~1 s (RTO target 4 h) | **pass** | Security owner (TL backend) via the Claude Code harness, output captured in the session transcript |

## Notes

- Drill #1 established the baseline procedure and confirmed the dump format,
  restore flags and verification query used by the runbook.
- Not yet exercised: full S1 (stop service → restore into `finance` → migrate
  → verify) and the production Cloud SQL restore — scheduled in the DR plan
  §5 (2026-Q4 and once IaC lands).
