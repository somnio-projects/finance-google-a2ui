# Nonconformity and Corrective Action (CAPA) Log

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 2.0 — 2026-09-21 |
| **Maps to** | ISO/IEC 27001 Cl. 10.1, 10.2 · SOC 2 CC4.2 |

## What is logged

Any deviation from a policy in this folder or from a gate: a red gate merged,
an expired exception, a missed drill/review/rotation, an audit finding, an
emergency change (post-hoc review), a missed objective target, an incident's
policy-related root cause. GitHub issues labelled `nonconformity` hold the
detail; this table is the index and the closure record.

## Process

1. Record (this table + issue) with the requirement violated.
2. Contain / correct the immediate effect.
3. Root cause (5-whys) and **corrective action** to prevent recurrence — a code, harness or policy change through a PR.
4. Verify effectiveness at the next audit/review; close.

## Log

| # | Date | Source | Nonconformity | Requirement | Correction | Corrective action (PR/issue) | Verified | Status |
|---|---|---|---|---|---|---|---|---|
| NC-1 | 2026-09-19 | soc2-audit run 3 | no incident response, BCP/DR, breach SLA, vendor, HR, AI-governance or ISMS documentation | Cl. 5–10; SOC 2 CC7.x, CC9.x, CC1.4 | — | `docs/compliance/` corpus + `infra/` in PR #2 | soc2 40→93, iso 64→92 | closed with PR #2 |
| NC-2 | 2026-09-19 | soc2-audit run 3 (D6) | `audit_events` retained indefinitely, no purge | DATA_RETENTION.md (new) | — | `AuditRepository.purge_older_than`, `make purge-audit`, `AUDIT_RETENTION_DAYS` (PR #2) | gate green | closed |
| NC-3 | 2026-09-19 | soc2-audit run 3 (C7) | MFA not enforced for admin operations at the API | ACCESS_CONTROL.md §2 | — | `amr` check in `_require_admin`, `AUTH_ADMIN_REQUIRE_MFA` default on in production (PR #2) | gate green | closed |
| NC-4 | 2026-09-19 | soc2-audit run 3 (E3) | no CODEOWNERS / PR template in repo | CHANGE_MANAGEMENT.md §3 | — | `.github/CODEOWNERS`, `pull_request_template.md`; ruleset enabled on `main` + `develop` 2026-09-19 | export in `evidence/` | closed |
| NC-5 | 2026-09-19 | python-best-practices run 3 | untyped token payload / JWKS at the auth boundary | .claude/rules/python/data-validation.md | — | `JwtClaims`, `JwksDocument`, `from_row` (PR #2) | best-practices 88→91 | closed |
| NC-6 | 2026-09-20 | iso27001-audit run 7 (A.8.10) | **The erasure procedure deleted from 2 of 7 tables while telling the data subject no copy remained.** `sessions`, `messages`, `portfolios`, `portfolio_lots` and `portfolio_transactions` survived erasure. `DATA_CLASSIFICATION.md` §2 listed neither, and its closing paragraph still called portfolio data a "future spec" two days after `models/portfolio.py` shipped | DATA_RETENTION.md §3; Cl. 8.1; A.8.10; A.5.12 | Erasure SQL extended to all 7 tables (3 reached by `ON DELETE CASCADE` verified in the **migrations**, not just the ORM); classification inventory extended to all 7; A.8.10 re-rated *Partially implemented* | `docs/compliance_catches_up` (this PR) | **not yet** — verification is the next ISO run | **open** — correction landed, corrective action outstanding |
| NC-7 | 2026-09-20 | iso27001-audit run 7 / soc2-audit run 7 | **Four documents asserted controls the code does not have.** (a) `AI_GOVERNANCE.md` §3 promised the agent was "disable-able with a feature flag"; the A2A route had no gate while six `/v1` routers did, so the incident runbook's 15-second containment did not work on the agent. (b) `CHANGE_MANAGEMENT.md` §7 described merge-triggered deploys 1 h 22 m after the CD trigger became `workflow_dispatch`-only. (c) SoA A.8.6 claimed "Cloud Run autoscaling" with `min = max = 1`; A.5.3 claimed "author ≠ reviewer enforced" while EX-1 waives it. (d) The SoA summary line said 69/7 where the table said 68/8 | Cl. 7.5.2 (documented information must be reviewed for adequacy); the corpus honesty rule in `docs/compliance/README.md` | Gate added to `api/a2a.py` with a mutation-checked test; the four documents corrected; SoA summary recounted from the rows | `docs/compliance_catches_up` (this PR) | **not yet** — verification is the next audit run | **open** — correction landed, corrective action outstanding |

**Root cause shared by NC-6 and NC-7 (5-whys, recorded 2026-09-21).** Eighteen
PRs merged on 2026-09-20; four touched `docs/compliance/`. *Why did the corpus
fall behind?* Because nothing fails when it does. Every other claim this
project makes is gated by regeneration or a test — the catalog contract, the
rate-limit ceiling, the rules index, the spelling scope — while a compliance
document asserting a control that does not exist passes a green gate. The
corpus is the last substantial body of claims in this repository verified only
by a human reading it.

**Corrective action (owner: TL backend, due 2026-10-31).** Not "be more
careful". Candidates, cheapest first:

1. A `repo.*` check that fails when a document names a route, flag key,
   Terraform variable or table that does not exist — the same anti-vacuity
   shape `infra/scripts/tests/` already uses.
2. `docs/compliance/**` added to `.github/CODEOWNERS` paths that require the
   security owner's review (it is already there — so the review happened and
   did not catch these, which is itself evidence that review is the wrong
   instrument for this class of defect).
3. A spec-template checklist item: a PR that adds a table adds its row to
   `DATA_CLASSIFICATION.md` §2 and `DATA_RETENTION.md` §1/§3. Weakest option,
   listed because it is free.

Until one of these exists, NC-6 and NC-7 stay **open**. Correcting the
documents is the *correction*; preventing recurrence is the corrective action,
and Cl. 10.2 distinguishes them.
