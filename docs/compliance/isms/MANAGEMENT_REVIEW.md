# Management Review

| | |
|---|---|
| **Owner** | Engineering management (chair) · Security owner (secretary) · **Version** 1.0 — 2026-09-19 |
| **Cadence** | semi-annual (March, September) and after any SEV-1 |
| **Maps to** | ISO/IEC 27001 Cl. 9.3 · SOC 2 CC1.2, CC4.2 |

## Standing agenda (Cl. 9.3.2)

1. Status of actions from the previous review
2. Changes in context: team, vendors, deployment target, data classes, program expectations
3. Objectives and metrics — [SECURITY_OBJECTIVES.md](SECURITY_OBJECTIVES.md)
4. Nonconformities and corrective actions — [NONCONFORMITY_LOG.md](NONCONFORMITY_LOG.md)
5. Audit results — [INTERNAL_AUDIT_PROGRAM.md](INTERNAL_AUDIT_PROGRAM.md)
6. Incidents and postmortems; exceptions open — [EXCEPTION_POLICY](../EXCEPTION_POLICY.md)
7. Risk register changes and treatment plan progress — [RISK_ASSESSMENT.md](../RISK_ASSESSMENT.md)
8. Interested-party feedback (Google program, contributors, reporters)
9. Resources needed (pentest budget, IaC time, training time)
10. Opportunities for improvement; decisions

Outputs: decisions, resource commitments, changes to objectives/policies —
recorded below and turned into GitHub issues.

## Minutes

### 2026-09-19 — Review #1 (foundation baseline) — conducted asynchronously in PR #2

This first review was **not a meeting**: the security owner prepared the
inputs and the proposed decisions below in the foundation pull request; the
review happens as the PR review, and the decisions take effect when engineering
management approves and merges it. Participants are the PR's author and
reviewers: Lautaro Bertuzzi (security owner, TL backend — prepared), Mario
Campbell (backend — reviewer), Guillermo Hilal (eng. management — approver).
From review #2 onward the review is a scheduled meeting with minutes taken live.

**Inputs reviewed:** first full SOC 2 (40) and ISO 27001 (64) readiness audits; security-audit 98; python-health 92; python-best-practices 88; risk register v1.0; restore drill #1.

**Proposed decisions (effective on merge)**

| # | Decision | Owner | Due |
|---|---|---|---|
| D-1 | Adopt this policy set (IS policy, SoA, risk register, runbooks) as the project ISMS; approval by merging PR #2 | Eng. management | with PR #2 |
| D-2 | Accept residual risk R-11 (single instance) until non-demo exposure; production HA/backups/private networking are part of the deploy epic GGU-29 | TL backend | GGU-29 |
| D-3 | Fund an external penetration test before the service is exposed beyond the demo; open the budget request | Eng. management | request 2026-09-19; test before exposure |
| D-4 | Execute DPAs with Google Cloud and Sentry before enabling staging telemetry | Eng. management | 2026-10-31 |
| D-5 | Nominate an independent Somnio reviewer for the first ISMS operation audit and tabletop | Eng. management | 2026-Q4 |
| D-6 | Re-run the five Somnio CLI audits after this remediation; target ≥ 90 each; record in the internal audit program | Security owner | before PR #2 merge |
| D-7 | Mario completes the security primer and adds his competence record in his first PR | Mario Campbell | first PR |

**Objectives:** O-1…O-10 adopted as written.

**Next review:** 2027-03 (or after the demo retrospective if a SEV-1 occurs).
