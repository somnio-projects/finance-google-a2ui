# Business Continuity Plan (incl. RPO/RTO targets)

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Approved by** engineering management |
| **Version** | 2.0 — 2026-09-21 · **Next review** 2027-09-19 or when the deployment target changes |
| **Maps to** | SOC 2 CC7.5, CC9.1, A1.2, A1.3 · ISO/IEC 27001 A.5.29, A.5.30 |

## 1. Critical functions and recovery objectives

| Function | Depends on | Impact of loss | **RPO** | **RTO** | Priority |
|---|---|---|---|---|---|
| API availability (`/v1/*`, health) | backend container, Postgres, identity provider | demo/showcase unavailable | — (stateless) | **4 h** | 1 |
| Audit trail integrity (`audit_events`) | Postgres | loss of accountability evidence | **24 h** (daily backup) → 1 h with Cloud SQL PITR | **4 h** | 1 |
| Feature-flag state | Postgres (+ env kill-switch) | endpoints revert to their coded defaults | 24 h | 4 h (defaults keep the service usable meanwhile) | 2 |
| Delivery pipeline (GitHub, CI) | GitHub Actions | cannot ship fixes | n/a (git is distributed) | 1 business day (fall back to local `make gate` + manual deploy) | 2 |
| Authentication | external IdP (OIDC) or shared secret | users cannot sign in | n/a | IdP SLA; fallback `jwt` provider for service tokens | 1 |

RPO/RTO are the **targets** the design must meet; the demo topology
(single instance) meets them via restore-from-backup, not failover — see
retained risk R-11 in [RISK_ASSESSMENT.md](RISK_ASSESSMENT.md).

## 2. Continuity strategy

- **Stateless service** — the backend holds no state beyond an in-process flag cache; any instance can be replaced by `docker compose up --build` or a Cloud Run revision within minutes.
- **Schema as code** — `alembic upgrade head` rebuilds the schema on an empty database; data returns from backup ([BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md)).
- **Degraded modes** — flags default in code (`require_feature(default=)`), so a lost `feature_flags` table degrades to the coded surface; the env kill-switch works with no database at all; a flag read against a down database falls back to the default instead of failing.
- **Alternate site** — production target is Google Cloud Run (regional) + Cloud SQL (ADR-F). Until IaC lands, the alternate site is *any* Docker host with the image and a restored dump; the runbook is the DR plan.
- **Communication during disruption** — Slack `#finance-google-a2ui-dev`; if Slack is down, email + phone per Somnio directory.

## 3. Roles

Same as the incident response plan: IC, technical lead, communications, scribe.

## 4. Testing

| Exercise | Cadence | Evidence |
|---|---|---|
| Restore drill (dump → scratch database → verify) | quarterly | [RESTORE_DRILL_LOG.md](RESTORE_DRILL_LOG.md) |
| Rebuild-from-scratch (empty DB + migrations + restore) | annually, with the DR drill | DR plan §5 |
| Tabletop (regional outage) | annually | [isms/INTERNAL_AUDIT_PROGRAM.md](isms/INTERNAL_AUDIT_PROGRAM.md) |

## 5. Production commitments (defined in `infra/`, applied with GGU-29)

Cloud SQL with automated daily backups + point-in-time recovery (RPO → 1 h),
high-availability configuration (regional failover), uptime checks on
`/readyz`. These are **database-tier** commitments and they move the database
half of R-11 from retained to treated; the plan is updated when they land.

### 5a. The compute tier has no redundancy — and that is deliberate

**Gap (G-BCP-1) · Owner: TL backend · Review date: 2026-10-31.**

GGU-83 pinned Cloud Run to `max_instances = 1` in **every** environment,
production included (`infra/environments/production.tfvars:11`,
`infra/main.tf:82`). Production's floor and ceiling are both one
(`min_instances = 1`), so there is exactly one container — `cpu = "1"`,
`memory = "512Mi"` (`infra/run.tf:97`) — serving every user of the service.
An earlier version of this section claimed "Cloud Run min-instances ≥ 1
across zones"; that cannot be true when the maximum is 1, and the claim is
withdrawn.

What follows from that, stated plainly:

- **No compute failover.** A crash, a bad revision or a zone event is a full
  outage until Cloud Run reschedules the single instance. The RTO for a
  compute-tier failure is Cloud Run's reschedule time, which we have not
  measured — it is **not** the 4 h RTO in §1, and it is not a failover.
- **No published throughput ceiling and no SLO.** Capacity is one container.
  Nothing in this corpus states what that is worth in requests per second or
  concurrent sessions, because nobody has measured it. We do not publish an
  availability or latency SLO for production, and must not imply one.
- **The database tier is unaffected.** Cloud SQL is `REGIONAL` outside dev
  (`infra/main.tf:23`) — a synchronous standby in a second zone. Database
  redundancy is real; compute redundancy is not. Do not read one as the other.

**Why the pin exists:** the in-process rate limiter counts hits in process
memory, so the effective per-principal budget is `max_instances` × the
configured limit. More than one instance silently multiplies the limit that
`backend/docs/SECURITY.md` documents. The pin makes the configuration match
the limiter's real capability rather than making the limiter correct.

**The condition that lifts it:** the shared limiter backing store (spec
`backend/0001` OD-2). When that lands, `max_instances` can rise and this
section is rewritten — those are one change, not two.

Tracked as risk **R-17** in [RISK_ASSESSMENT.md](RISK_ASSESSMENT.md), and
paired with the documented limit by
`infra/scripts/tests/test_rate_limit_ceiling.sh`, so raising the ceiling
without revisiting both declarations turns the gate red.

**These commitments are production's, and only production's.** The `dev`
environment defined in
[specs/infra/0001-dev-environment.md](../../specs/infra/0001-dev-environment.md)
has none of them — zonal database, no PITR, scale-to-zero, no uptime check —
and carries no availability commitment. It is a disposable proof of concept
with synthetic data; a dev outage is not a continuity event and does not
invoke this plan. Applying dev therefore does **not** move R-11.
