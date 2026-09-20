# Data Retention and Deletion

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 C1.2, P4.2, P4.3 · ISO/IEC 27001 A.8.10 · GDPR Art. 5(1)(e), 17 (reference framework) |

## 1. Retention schedule

| Data | Class | Retention | Mechanism | Owner |
|---|---|---|---|---|
| `audit_events` | Confidential | **400 days** (13 months — covers an annual audit cycle plus one quarter) | `AuditRepository.purge_older_than(cutoff)` invoked by `make purge-audit` / the scheduled job (`python -m app.jobs.purge_audit`), monthly | TL backend |
| `feature_flags` | Internal | while the flag exists; rows for removed routes deleted in the PR that removes the route | migration / admin PUT | feature owner |
| Application logs | Internal | local: container lifetime; **dev: 30 days**; staging/production: **90 days** in Cloud Logging | log bucket retention (CLOUD_SERVICES §4) | TL backend |
| Sentry events | Internal | Sentry plan default (90 days) | vendor setting | TL backend |
| Database backups | Confidential | 14 days (local dumps) / 30 days (Cloud SQL) | [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) | TL backend |
| Incident evidence | Confidential | 12 months after closure, unless legal hold | restricted folder, deleted by IC | IC |
| CI artifacts (coverage, SBOM, SARIF) | Internal | 90 days | GitHub artifact retention | TL backend |
| Somnio CLI audit reports | Internal | kept by the security owner locally; summarised in the internal audit program | git-ignored `backend/reports/` | Security owner |
| Token claims (`email`) | Confidential | never stored — request lifetime only | design | — |

Longer retention needs an approved exception ([EXCEPTION_POLICY.md](EXCEPTION_POLICY.md)).

## 2. Purge mechanism

`audit_events` are the only rows with a time-based retention. The purge is a
repository method (parameterised `DELETE … WHERE created_at < :cutoff`,
tested against real PostgreSQL) exposed as a maintenance command:

```bash
cd backend && make purge-audit                 # uses AUDIT_RETENTION_DAYS from settings (default 400)
```

In production the same module runs monthly as a Cloud Scheduler → Cloud Run
job (`infra/run.tf`, apply with GGU-29). Each run logs
`audit_events_purged count=<n> retention_days=<d> cutoff=<iso date>`.
The purge itself is not audited as a row (it would never age out); the log
line plus the job history are the record.

## 3. Deletion / erasure requests

A user (or the Google program on behalf of a reviewer account) may request
erasure of the data tied to a subject:

1. Request arrives at `security@somniosoftware.com`; the security owner opens a private issue labelled `erasure`.
2. Identity is confirmed through the IdP (the subject id, not an email typed in the request).
3. `DELETE FROM audit_events WHERE subject = :sub` and `UPDATE feature_flags SET updated_by = 'erased' WHERE updated_by = :sub` are run through a reviewed one-off script; counts are recorded in the issue.
4. Backups containing the subject age out within their retention (≤ 30 days); the issue notes the date after which no copy exists.
5. Response to the requester within **30 days**.

Audit rows for **security-relevant** actions may be retained if legally
required (legitimate interest); the decision and its reason go in the issue.

## 4. Secure disposal

Database dumps are deleted with the OS secure-delete equivalent (`rm` on an
encrypted volume is accepted); cloud backups are deleted by the provider at
retention end; decommissioned volumes are destroyed (`docker volume rm`,
Cloud SQL instance deletion).
