# Data Retention and Deletion

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 2.0 — 2026-09-21 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 C1.2, P4.2, P4.3 · ISO/IEC 27001 A.8.10 · GDPR Art. 5(1)(e), 17 (reference framework) |

## 1. Retention schedule

| Data | Class | Retention | Mechanism | Owner |
|---|---|---|---|---|
| `audit_events` | Confidential | **400 days** (13 months — covers an annual audit cycle plus one quarter) | `AuditRepository.purge_older_than(cutoff)` invoked by `make purge-audit` / the scheduled job (`python -m app.jobs.purge_audit`), monthly | TL backend |
| `feature_flags` | Internal | while the flag exists; rows for removed routes deleted in the PR that removes the route | migration / admin PUT | feature owner |
| `sessions` | Confidential | **no time-based retention** — kept until the subject deletes the session (`DELETE /v1/sessions/{id}`) or requests erasure (§3) | subject-initiated only | TL backend |
| `messages` | Confidential (free-text user input) | as `sessions` — the row is reachable only through its session and is removed with it (`ON DELETE CASCADE`, `alembic/versions/20260919_0004_sessions.py:67-71`) | cascade from `sessions` | TL backend |
| `portfolios` | Confidential | **no time-based retention** — one row per subject (`uq_portfolios_subject`), kept until erasure (§3) | erasure only | TL backend |
| `portfolio_lots` | Confidential | as `portfolios` — removed with the parent (`ON DELETE CASCADE`, `20260920_0005_portfolios.py:77-81`) | cascade from `portfolios` | TL backend |
| `portfolio_transactions` | Confidential | as `portfolios` — removed with the parent (`ON DELETE CASCADE`, `20260920_0005_portfolios.py:99-103`) | cascade from `portfolios` | TL backend |
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
3. The statements below are run **in this order**, in one transaction, through a reviewed one-off script; the row count of each is recorded in the issue.
4. Backups containing the subject age out within their retention (≤ 30 days); the issue notes the date after which no copy exists.
5. Response to the requester within **30 days**.

**The statements. All seven tables, or the promise in step 4 is false:**

```sql
BEGIN;
-- Portfolio aggregate. The two child tables are ON DELETE CASCADE, so they go
-- with the parent; deleting them separately is unnecessary, not optional.
DELETE FROM portfolios    WHERE subject = :sub;  -- cascades: portfolio_lots, portfolio_transactions
-- Conversations. `messages` has no subject column of its own — it is reachable
-- only through its session, and cascades from it.
DELETE FROM sessions      WHERE subject = :sub;  -- cascades: messages
-- Audit trail, subject to the legal-hold carve-out below.
DELETE FROM audit_events  WHERE subject = :sub;
-- Not ownership: `updated_by` records which admin last toggled a flag. The row
-- is not the subject's data, so the identifier is scrubbed and the flag stays.
UPDATE feature_flags SET updated_by = 'erased' WHERE updated_by = :sub;
COMMIT;
```

**Why this list is exactly seven.** The tables are enumerated from
`backend/src/app/models/` — `audit_events`, `feature_flags`, `sessions`,
`messages`, `portfolios`, `portfolio_lots`, `portfolio_transactions`. The
three cascades are declared in the **migrations**, not merely in the ORM
models, so they are real DDL: `20260919_0004_sessions.py:67-71` and
`20260920_0005_portfolios.py:77-81,99-103`. Anything that stores subject data
and is not in this list makes step 4 a false statement to a data subject.

> **Correction, 2026-09-21.** Until this revision, this procedure named only
> `audit_events` and `feature_flags` while step 4 told the requester that no
> copy remains. Five tables survived erasure — `sessions`, `messages`,
> `portfolios`, `portfolio_lots`, `portfolio_transactions` — three of which
> had shipped in the two days before the audit. The defect was in the
> document, not the schema. Raised as **NC-6** in
> [isms/NONCONFORMITY_LOG.md](isms/NONCONFORMITY_LOG.md).

**When a table is added, this procedure is part of the migration's PR.** A new
table holding subject data and no row here is the same defect returning. The
spec template's §5 "Security notes" is where that is caught.

**Not yet automated (gap G-RET-1) · Owner: TL backend · Review date:
2026-10-31.** Erasure is a reviewed manual script, not a tested code path:
there is no `POST /v1/me/erasure-requests`, no repository method and no test
that proves all seven tables are emptied. The manual procedure is adequate at
demo scale with a handful of subjects; it does not scale and it is not
mechanically verified, which is exactly how the previous version stayed wrong
for two days. Automating it is the treatment.

Audit rows for **security-relevant** actions may be retained if legally
required (legitimate interest); the decision and its reason go in the issue.

## 4. Secure disposal

Database dumps are deleted with the OS secure-delete equivalent (`rm` on an
encrypted volume is accepted); cloud backups are deleted by the provider at
retention end; decommissioned volumes are destroyed (`docker volume rm`,
Cloud SQL instance deletion).
