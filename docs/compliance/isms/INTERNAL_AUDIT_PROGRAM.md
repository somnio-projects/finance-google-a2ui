# Internal Audit Program and Records

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | ISO/IEC 27001 Cl. 9.1, 9.2 · SOC 2 CC4.1, CC4.2 |

## Program

| Audit | Method | Cadence | Auditor | Independence |
|---|---|---|---|---|
| Technical controls | Somnio CLI `security-audit`, `python-health-audit`, `python-best-practices` (read-only, evidence-based) | every foundation milestone; at least quarterly | run by the security owner, reviewed by the backend reviewer | tool-driven; reviewer ≠ author |
| Readiness | Somnio CLI `soc2-audit`, `iso27001-audit` | same | same | same |
| ISMS operation (Cl. 9.2) | checklist review of this folder: review dates, open exceptions, access review done, drills done, vendor reviews, competence records, objectives measured | semi-annual, before each management review | a Somnio engineer **outside** the project team (first: to be nominated by eng. management for 2026-Q4) | organisational independence |
| Branch-protection and IAM export | `gh api repos/.../rulesets` and (later) `gcloud projects get-iam-policy` exported to `docs/compliance/evidence/` | with each ISMS audit | security owner | evidence for A.8.32 / A.5.18 |
| Tabletop exercise | leaked-secret and regional-outage scenarios | annual | IC + team | recorded here |

Findings become entries in the [nonconformity log](NONCONFORMITY_LOG.md);
scores feed [SECURITY_OBJECTIVES.md](SECURITY_OBJECTIVES.md) O-6.

## Records

| Date | Audit | Scope / commit | Result | Findings → actions |
|---|---|---|---|---|
| 2026-09-18 | `security-audit` (run 2) | `feat/backend_fastapi_foundation` before feature flags | **98/100** | Dependabot, pre-commit, gitleaks config, Trivy, base-image upgrade (all landed in `7af8331`) |
| 2026-09-19 | `python-health-audit` (run 3) | after feature flags (`9169280`) | **92/100** | no pre-push hook / no agent model pin noted — accepted (PostToolUse hook + CI cover it) |
| 2026-09-19 | `python-best-practices` (run 3) | `9169280` | **88/100** | boundary validation (JwtClaims, JwksDocument, `from_row`), CQS in cache/JWKS, `Final`, fixtures — landed in `02d1836`; re-audit in progress |
| 2026-09-19 | `soc2-audit` (run 3, first full 10-family audit) | `9169280` | **40/100** | this compliance corpus, CODEOWNERS, PR template, scheduled scan, Semgrep, retention purge, admin MFA, restore drill — re-audit pending |
| 2026-09-19 | `iso27001-audit` (run 3) | `9169280` | **64/100** | same remediation + ISMS artifacts (this folder) — re-audit pending |
| 2026-09-19 | Backup/restore drill #1 | local compose | pass | see RESTORE_DRILL_LOG.md |
| 2026-09-19 | `python-best-practices` (run 4) | after `02d1836` | **90/100** | stricter basedpyright, CQS split, keyword-only constructors (`4944768`); run 5 pending |
| 2026-09-19 | `soc2-audit` (run 4) | after the compliance corpus (`82534de`) | **78/100** (Largely Ready) | remaining: Family F infrastructure (IaC), external pentest, DPAs, IAM/revocation |
| 2026-09-19 | `iso27001-audit` (run 4) | `82534de` | **86/100** (Certification-Ready) | Category A scored from a stale snapshot — re-run (run 5) in progress; H/I need IaC + DPAs |
| 2026-09-19 | `security-audit` (run 3) | final tree | **98/100** | no new findings |
| 2026-09-19 | `python-best-practices` (run 5) | `4944768` | **91/100** | explicit `Final[...]` type arguments (cosmetic) |
| 2026-09-19 | `python-health-audit` (run 4) | `4944768` | **91/100** | no new findings |
| 2026-09-19 | `soc2-audit` (run 6, run 5 aborted by the usage limit) | final tree incl. `infra/` (`4cd5af4`) | **93/100** (Audit-Ready) | remaining: external pentest (G2), `main` ruleset enforcement (E3/E4), DPAs (I3), rotation subscriber (F9), IaC apply (H5/H7) |
| 2026-09-19 | `backend-reviewer` round 2 | final tree | FLAGGED → fixed | `audit_events.target` (0003), `feature_flag.list` audited, purge job into `app/jobs`, spec/docs sync, branch-protection evidence |

Reports are kept by the security owner (`backend/reports/`, git-ignored, 90
days) and attached to the PR that addressed them.

## Next scheduled

- Re-run of all five audits on the final foundation tree (before PR #2 merge).
- ISMS operation audit + tabletop: 2026-Q4 (auditor to be nominated).
