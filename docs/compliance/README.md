# Compliance corpus — SOC 2 (TSC 2017) · ISO/IEC 27001:2022

This folder is the **management-side** half of the security program. The
**engineering-side** half — the controls implemented in code and verified by
tests — is the control matrix in [`backend/docs/SECURITY.md`](../../backend/docs/SECURITY.md);
the Statement of Applicability links the two.

Every document here has a header with **Owner · Approved by · Version · Last
review · Next review**. "Approved" means the named role signed off in the PR
that merged the document; the merge commit is the signature. Status words are
used honestly: *implemented* (evidence in repo or linked), *planned* (owner and
date named), *not applicable* (reason given). Nothing here claims an external
attestation the project does not have.

## Index

### Governance & program (A)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [INFORMATION_SECURITY_POLICY.md](INFORMATION_SECURITY_POLICY.md) — policy statement, scope, objectives, roles/RACI, management commitment, review cadence | CC1.1, CC1.3, CC5.1 | Cl. 5.2, 5.3, 6.2, A.5.1, A.5.2, A.5.4 |
| [RISK_ASSESSMENT.md](RISK_ASSESSMENT.md) — methodology, asset inventory, risk register, treatment plan | CC3.1, CC3.2 | Cl. 6.1.2, 6.1.3, 8.2, 8.3 |
| [EXCEPTION_POLICY.md](EXCEPTION_POLICY.md) — how a control is waived, by whom, for how long | CC5.3 | Cl. 6.1.3 |
| [CODE_OF_CONDUCT.md](../../CODE_OF_CONDUCT.md) | CC1.1 | A.5.4 |

### People (B)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [SECURITY_TRAINING.md](SECURITY_TRAINING.md) — onboarding primer, mandatory topics, cadence, attestation record | CC1.4 | A.6.3, Cl. 7.2, 7.3 |
| [CONFIDENTIALITY.md](CONFIDENTIALITY.md) — confidentiality obligations, reference to Somnio HR/Legal agreements | CC1.4 | A.6.2, A.6.6 |
| [DEVICE_POLICY.md](DEVICE_POLICY.md) — workstation baseline for contributors | CC1.4 | A.8.1 |
| [ONBOARDING_OFFBOARDING.md](ONBOARDING_OFFBOARDING.md) — access checklist joiners/leavers | CC6.2, CC6.3 | A.5.18, A.6.5 |

### Identity & access (C)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [ACCESS_CONTROL.md](ACCESS_CONTROL.md) — scope matrix, admin/MFA rule, token lifetime, revocation, quarterly access review, secret rotation | CC6.1–CC6.3 | A.5.15, A.5.17, A.5.18, A.8.2 |

### Data (D)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md) — Public / Internal / Confidential / Restricted, handling rules, field inventory | C1.1, C1.2 | A.5.12, A.5.13 |
| [DATA_RETENTION.md](DATA_RETENTION.md) — retention periods, purge mechanism, erasure requests | C1.2 | A.8.10 |
| [DATA_RESIDENCY_AND_TENANCY.md](DATA_RESIDENCY_AND_TENANCY.md) — region, single-tenancy declaration, encryption at rest/in transit | C1.1 | A.8.24 |
| [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) — backup schedule, encryption, restore runbook | A1.2 | A.8.13 |
| [RESTORE_DRILL_LOG.md](RESTORE_DRILL_LOG.md) — executed drills | A1.2, A1.3 | A.8.13, A.8.14 |

### Secure development & change (E)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [CHANGE_MANAGEMENT.md](CHANGE_MANAGEMENT.md) — SDLC, environments, branch protection, CODEOWNERS, release process | CC8.1 | A.8.25, A.8.31, A.8.32 |
| [EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md) — break-glass path and post-hoc review | CC8.1 | A.8.32 |
| [PATCH_POLICY.md](PATCH_POLICY.md) — CVE fix SLAs by severity | CC7.1 | A.8.8 |

### Infrastructure, vulnerability & vendors (F, G, I)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [CLOUD_SERVICES.md](CLOUD_SERVICES.md) — approved services, shared responsibility, production topology commitments, logging retention, alerting | CC6.6, CC7.2 | A.5.23, A.8.15, A.8.16, A.8.20–A.8.22 |
| [VULNERABILITY_MANAGEMENT.md](VULNERABILITY_MANAGEMENT.md) — scanners, cadence, SAST, pentest plan, evidence sharing | CC7.1 | A.8.8, A.8.29, A.5.35 |
| [VENDOR_MANAGEMENT.md](VENDOR_MANAGEMENT.md) — supplier register, risk review, DPAs, subprocessor list | CC9.2 | A.5.19–A.5.22 |

### Incidents & continuity (H)

| Document | SOC 2 | ISO 27001 |
|---|---|---|
| [INCIDENT_RESPONSE_PLAN.md](INCIDENT_RESPONSE_PLAN.md) — severities, roles, escalation, containment runbooks, evidence handling | CC7.3, CC7.4 | A.5.24–A.5.26, A.5.28 |
| [POSTMORTEM_PROCESS.md](POSTMORTEM_PROCESS.md) — blameless postmortems, template, action tracking | CC7.4 | A.5.27 |
| [BREACH_NOTIFICATION_SLA.md](BREACH_NOTIFICATION_SLA.md) — who is told what, by when | CC7.4, CC9.1 | A.5.26 |
| [BUSINESS_CONTINUITY_PLAN.md](BUSINESS_CONTINUITY_PLAN.md) — critical functions, RPO/RTO, continuity strategy | CC7.5, CC9.1 | A.5.29, A.5.30 |
| [DISASTER_RECOVERY_PLAN.md](DISASTER_RECOVERY_PLAN.md) — recovery procedures per scenario, drill schedule | CC7.5, A1.2, A1.3 | A.5.30, A.8.13, A.8.14 |

### AI governance (J)

| Document | SOC 2 | ISO 27001 / 42001 |
|---|---|---|
| [AI_GOVERNANCE.md](AI_GOVERNANCE.md) — where AI is used, human gates, audit trail, accuracy/bias review | CC1.x, CC4.x | A.5.1, A.8.29 |
| [AI_DATA_HANDLING.md](AI_DATA_HANDLING.md) — what data reaches which model, training non-use, PII controls | P-series | A.8.10, A.8.11 |

### ISMS artifacts (K)

| Document | ISO 27001 |
|---|---|
| [isms/ISMS_SCOPE.md](isms/ISMS_SCOPE.md) | Cl. 4.3 |
| [isms/STATEMENT_OF_APPLICABILITY.md](isms/STATEMENT_OF_APPLICABILITY.md) — all 93 Annex A controls | Cl. 6.1.3 d |
| [isms/SECURITY_OBJECTIVES.md](isms/SECURITY_OBJECTIVES.md) — measurable objectives and their metrics | Cl. 6.2, 9.1 |
| [isms/DOCUMENT_CONTROL.md](isms/DOCUMENT_CONTROL.md) — how documented information is created, approved, versioned | Cl. 7.5 |
| [isms/INTERNAL_AUDIT_PROGRAM.md](isms/INTERNAL_AUDIT_PROGRAM.md) — audit plan and records | Cl. 9.2 |
| [isms/MANAGEMENT_REVIEW.md](isms/MANAGEMENT_REVIEW.md) — agenda, minutes | Cl. 9.3 |
| [isms/NONCONFORMITY_LOG.md](isms/NONCONFORMITY_LOG.md) — CAPA log | Cl. 10.1, 10.2 |
| [isms/COMPETENCE_RECORDS.md](isms/COMPETENCE_RECORDS.md) — training/awareness attestations | Cl. 7.2, 7.3 |

## Review cadence

All policies: **annual** review (next: 2027-09) or on a material change (new
data class, new vendor, new deployment target). The internal audit program
runs the Somnio CLI `soc2-audit` and `iso27001-audit` on every foundation
milestone and at least quarterly; scores and actions are recorded in
[`isms/INTERNAL_AUDIT_PROGRAM.md`](isms/INTERNAL_AUDIT_PROGRAM.md).
