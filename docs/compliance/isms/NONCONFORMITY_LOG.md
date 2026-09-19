# Nonconformity and Corrective Action (CAPA) Log

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 |
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
| NC-1 | 2026-09-19 | soc2-audit run 3 | no incident response, BCP/DR, breach SLA, vendor, HR, AI-governance or ISMS documentation | Cl. 5–10; SOC 2 CC7.x, CC9.x, CC1.4 | — | `docs/compliance/` corpus + `infra/` in PR #2 | soc2 40→93, iso 64→86 (re-audit) | closing with PR #2 |
| NC-2 | 2026-09-19 | soc2-audit run 3 (D6) | `audit_events` retained indefinitely, no purge | DATA_RETENTION.md (new) | — | `AuditRepository.purge_older_than`, `make purge-audit`, `AUDIT_RETENTION_DAYS` (PR #2) | gate green | closed |
| NC-3 | 2026-09-19 | soc2-audit run 3 (C7) | MFA not enforced for admin operations at the API | ACCESS_CONTROL.md §2 | — | `amr` check in `_require_admin`, `AUTH_ADMIN_REQUIRE_MFA` default on in production (PR #2) | gate green | closed |
| NC-4 | 2026-09-19 | soc2-audit run 3 (E3) | no CODEOWNERS / PR template in repo | CHANGE_MANAGEMENT.md §3 | — | `.github/CODEOWNERS`, `pull_request_template.md`; ruleset export at first ISMS audit | ruleset export pending | closing |
| NC-5 | 2026-09-19 | python-best-practices run 3 | untyped token payload / JWKS at the auth boundary | .claude/rules/python/data-validation.md | — | `JwtClaims`, `JwksDocument`, `from_row` (`02d1836`) | re-audit pending | closing |
