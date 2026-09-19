# Information Security Objectives and Metrics

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Reviewed** at every management review |
| **Maps to** | ISO/IEC 27001 Cl. 6.2, 9.1 · SOC 2 CC4.1 |

| # | Objective | Metric | Target | Measured by | Current (2026-09-19) |
|---|---|---|---|---|---|
| O-1 | Every request authenticated, every privileged action audited | routes without `PrincipalDep` (excl. health/docs); admin actions without an audit row | 0 / 0 | `backend-reviewer` per PR; integration tests | 0 / 0 |
| O-2 | No vulnerable dependency or image on `main` past SLA | findings older than PATCH_POLICY SLA | 0 | weekly scheduled scan, Dependabot | 0 (pip-audit clean, Trivy clean) |
| O-3 | No secret ever reaches the repository | gitleaks findings on `main` | 0 | pre-commit + CI + weekly | 0 |
| O-4 | Code quality gate never regresses | branch coverage; ruff/pyright errors; files > 150 lines | 100 % / 0 / 0 | `make gate` == CI | 100 % / 0 / 0 (155 tests) |
| O-5 | Recoverability | quarterly restore drill executed and passed; RTO in drill | 4 drills/yr, RTO ≤ 4 h | RESTORE_DRILL_LOG.md | 1/1 passed, ~1 s |
| O-6 | Readiness scores | Somnio CLI `security-audit`, `soc2-audit`, `iso27001-audit`, `python-health-audit`, `python-best-practices` | each ≥ 90 | INTERNAL_AUDIT_PROGRAM.md | 98 / 40→re-audit pending / 64→re-audit pending / 92 / 88→re-audit pending |
| O-7 | Incident readiness | SEV-1/2 incidents with postmortem within 10 business days | 100 % | POSTMORTEM_PROCESS.md log | n/a (no incidents) |
| O-8 | People | contributors with current security-primer attestation | 100 % | COMPETENCE_RECORDS.md | 1/2 (Mario pending, joined 2026-09-18) |
| O-9 | Access hygiene | quarterly access review done; leavers deprovisioned within 1 business day | 4/yr; 100 % | ACCESS_CONTROL.md §6; access issues | Q3 review done |
| O-10 | Vendor governance | vendors with completed initial review; DPAs executed | 100 %; 100 % | VENDOR_MANAGEMENT.md | 100 %; 0/2 due 2026-10-31 |

Objectives are reviewed and, if needed, re-set at each
[management review](MANAGEMENT_REVIEW.md). A missed target becomes an entry in
the [nonconformity log](NONCONFORMITY_LOG.md) with a corrective action.
