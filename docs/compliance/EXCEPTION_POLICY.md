# Exception (waiver) Policy

| | |
|---|---|
| **Owner** | Security owner (TL backend) |
| **Approved by** | Engineering management |
| **Version** | 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC5.3 · ISO/IEC 27001 Cl. 6.1.3, A.5.1 |

## When an exception is needed

Any deviation from a documented control or from a gate threshold:
lowering `fail_under`, disabling a ruff rule, adding `# pragma: no cover`
without the one-line reason, widening CORS, skipping a migration, merging
with a red CI job, adding a public route, extending a retention period, or
using a vendor not in the supplier register.

Some thresholds are **not waivable per feature PR** at all (see
`backend/CLAUDE.md` → "Do not touch"): coverage `fail_under`, the ruff rule
set, `typeCheckingMode`. Changing them is a team decision recorded here as a
*permanent* exception with a new baseline, not a waiver.

## Process

1. **Request** — open a GitHub issue with label `exception` using this template:
   - Control / rule affected and where it is defined
   - Business justification (why the control cannot be met now)
   - Compensating controls while the exception is active
   - Risk assessment (likelihood × impact per [RISK_ASSESSMENT.md](RISK_ASSESSMENT.md))
   - Remediation plan and **expiry date** (max 90 days; permanent exceptions need management approval)
2. **Approval authority**
   - Risk score ≤ 6 → security owner
   - 7–12 → security owner **and** engineering management
   - ≥ 13 → not grantable; treat the risk instead
3. **Record** — the approved issue number is referenced in the PR that relies on the exception (`Exception: #123`) and in the [nonconformity log](isms/NONCONFORMITY_LOG.md).
4. **Expiry** — the issue stays open until remediation lands; the weekly scheduled-scan job is the reminder cadence. An expired exception is a nonconformity.
5. **Review** — open exceptions are an agenda item in every [management review](isms/MANAGEMENT_REVIEW.md).

## Currently active exceptions

| # | Control | Justification | Compensating control | Expires | Approver |
|---|---|---|---|---|---|
| — | none | | | | |

Retained risk R-11 (single instance during the demo) is documented in the
risk register, not here: it is an accepted risk, not a waived control.
