# Statement of Applicability — ISO/IEC 27001:2022 Annex A

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Approved by** engineering management |
| **Version** | 1.0 — 2026-09-19 · **Next review** 2027-09-19 or after any risk-register change |
| **Scope** | [ISMS_SCOPE.md](ISMS_SCOPE.md) |
| **Maps to** | ISO/IEC 27001 Cl. 6.1.3 d) |

All **93** Annex A controls are listed. Applicability follows the risk
assessment ([../RISK_ASSESSMENT.md](../RISK_ASSESSMENT.md)); "Not applicable"
is used only where the control's subject does not exist in scope (physical
facilities are the cloud provider's; there is no outsourced development).
Status words: *Implemented* — evidence in the repository or linked policy;
*Implemented (organisational/delegated)* — operated by Somnio HR/IT or the
cloud provider under the shared-responsibility model, referenced from a policy
here; *Partially implemented* — control exists but a named piece is planned;
*Planned* — owner and date named, nothing operating yet.

**Summary:** 69 implemented · 5 implemented (organisational/delegated) · 7 partially implemented · 1 planned · 11 not applicable.

| Ref | Control | Applicability | Status | Justification / evidence |
|---|---|---|---|---|
| A.5.1 | Policies for information security | Applicable | Implemented | docs/compliance/INFORMATION_SECURITY_POLICY.md + policy set; backend/docs/SECURITY.md control matrix |
| A.5.2 | Information security roles and responsibilities | Applicable | Implemented | RACI in INFORMATION_SECURITY_POLICY.md §4; CONTRIBUTORS.md; .github/CODEOWNERS |
| A.5.3 | Segregation of duties | Applicable | Implemented | author ≠ reviewer enforced by CODEOWNERS + the **active** `protected-branches` ruleset on `main` and `develop` (`evidence/branch-protection-ruleset.json`); admin scope separate from user scope (ACCESS_CONTROL.md) |
| A.5.4 | Management responsibilities | Applicable | Implemented | management commitment §5 of the IS policy; approval by merge; MANAGEMENT_REVIEW.md |
| A.5.5 | Contact with authorities | Applicable | Implemented | BREACH_NOTIFICATION_SLA.md (regulator row, coordinated by Somnio legal) |
| A.5.6 | Contact with special interest groups | Applicable | Implemented | GitHub Security Advisories, Dependabot/OSV feeds, OWASP rule sets via Semgrep (VULNERABILITY_MANAGEMENT.md) |
| A.5.7 | Threat intelligence | Applicable | Implemented | Dependabot, pip-audit, Trivy, gitleaks, scheduled scan (.github/workflows/*) |
| A.5.8 | Information security in project management | Applicable | Implemented | specs/TEMPLATE.md §5 Security notes mandatory before code; .claude/rules/backend/sdd.md |
| A.5.9 | Inventory of information and other associated assets | Applicable | Implemented | RISK_ASSESSMENT.md §2 asset inventory; DATA_CLASSIFICATION.md §2 field inventory |
| A.5.10 | Acceptable use of information and other associated assets | Applicable | Implemented | DATA_CLASSIFICATION.md §4 handling rules; DEVICE_POLICY.md; CONFIDENTIALITY.md |
| A.5.11 | Return of assets | Applicable | Implemented | ONBOARDING_OFFBOARDING.md leaver checklist |
| A.5.12 | Classification of information | Applicable | Implemented | DATA_CLASSIFICATION.md §1 |
| A.5.13 | Labelling of information | Applicable | Implemented | DATA_CLASSIFICATION.md §3 (SecretStr, DTO docstrings, inventory) |
| A.5.14 | Information transfer | Applicable | Implemented | TLS everywhere (DATA_RESIDENCY_AND_TENANCY.md §3); handling rules for sharing (DATA_CLASSIFICATION.md §4) |
| A.5.15 | Access control | Applicable | Implemented | ACCESS_CONTROL.md; api/deps.py PrincipalDep; tests |
| A.5.16 | Identity management | Applicable | Implemented (delegated) | identity lifecycle at the OIDC IdP; API stores only `sub`; ONBOARDING_OFFBOARDING.md for staff identities |
| A.5.17 | Authentication information | Applicable | Implemented | token verification in auth/providers/*; secret rotation and IdP password/MFA standards in ACCESS_CONTROL.md §3 |
| A.5.18 | Access rights | Applicable | Implemented | provisioning via access issues; quarterly review table; revocation = IdP + secret rotation (ACCESS_CONTROL.md §5–6) |
| A.5.19 | Information security in supplier relationships | Applicable | Implemented | VENDOR_MANAGEMENT.md §1–2 register and review process |
| A.5.20 | Addressing information security within supplier agreements | Applicable | Partially implemented | DPAs listed with status; Google Cloud and Sentry DPAs due 2026-10-31 (VENDOR_MANAGEMENT.md) |
| A.5.21 | Managing information security in the ICT supply chain | Applicable | Implemented | pinned lockfiles, pip-audit, Trivy, SBOM in scheduled scan (VENDOR_MANAGEMENT.md §4) |
| A.5.22 | Monitoring, review and change management of supplier services | Applicable | Implemented | Dependabot weekly; annual vendor review |
| A.5.23 | Information security for use of cloud services | Applicable | Implemented | CLOUD_SERVICES.md approved services, shared responsibility, topology commitments |
| A.5.24 | Information security incident management planning and preparation | Applicable | Implemented | INCIDENT_RESPONSE_PLAN.md |
| A.5.25 | Assessment and decision on information security events | Applicable | Implemented | severity matrix + breach checklist (IR plan §1, BREACH_NOTIFICATION_SLA.md) |
| A.5.26 | Response to information security incidents | Applicable | Implemented | IR plan §3–4 runbooks; EMERGENCY_CHANGE.md |
| A.5.27 | Learning from information security incidents | Applicable | Implemented | POSTMORTEM_PROCESS.md; risk register updated after incidents |
| A.5.28 | Collection of evidence | Applicable | Implemented | IR plan §5 evidence handling and chain of custody |
| A.5.29 | Information security during disruption | Applicable | Implemented | BUSINESS_CONTINUITY_PLAN.md |
| A.5.30 | ICT readiness for business continuity | Applicable | Partially implemented | DR plan + restore drill #1 done; Cloud SQL REGIONAL HA + PITR defined in `infra/database.tf` — IaC committed in `infra/` (Terraform, validated in CI) — **not applied yet**, first apply with GGU-29 (retained risk R-11) |
| A.5.31 | Legal, statutory, regulatory and contractual requirements | Applicable | Implemented | GDPR as reference framework in DATA_RETENTION.md and BREACH_NOTIFICATION_SLA.md; Apache-2.0 LICENSE; Google program terms in CONFIDENTIALITY.md |
| A.5.32 | Intellectual property rights | Applicable | Implemented | LICENSE (Apache-2.0), dependency licences via SBOM, contributor agreements (CONFIDENTIALITY.md) |
| A.5.33 | Protection of records | Applicable | Implemented | audit_events insert-only API with retention purge (DATA_RETENTION.md); git history on `main` protected once the ruleset is enforced (see A.5.3) |
| A.5.34 | Privacy and protection of PII | Applicable | Implemented | data minimisation, no PII in logs/Sentry, erasure procedure (DATA_CLASSIFICATION.md, DATA_RETENTION.md §3, AI_DATA_HANDLING.md) |
| A.5.35 | Independent review of information security | Applicable | Planned | internal readiness review by a Somnio reviewer outside the team 2026-Q4; external pentest before non-demo exposure (VULNERABILITY_MANAGEMENT.md §2) |
| A.5.36 | Compliance with policies, rules and standards for information security | Applicable | Implemented | ship gate == CI == .claude/ship-gate.json; PostToolUse hook; CODEOWNERS; NONCONFORMITY_LOG.md |
| A.5.37 | Documented operating procedures | Applicable | Implemented | backend/README.md, backend/docs/*.md runbooks, BACKUP_AND_RECOVERY.md, DR plan |
| A.6.1 | Screening | Applicable | Implemented (organisational) | Somnio HR hiring process; out of repository scope (CONFIDENTIALITY.md) |
| A.6.2 | Terms and conditions of employment | Applicable | Implemented (organisational) | Somnio employment/contractor agreements with confidentiality clauses; checked at onboarding |
| A.6.3 | Information security awareness, education and training | Applicable | Implemented | SECURITY_TRAINING.md; COMPETENCE_RECORDS.md |
| A.6.4 | Disciplinary process | Applicable | Implemented (organisational) | Somnio HR process referenced in CONFIDENTIALITY.md and CODE_OF_CONDUCT.md |
| A.6.5 | Responsibilities after termination or change of employment | Applicable | Implemented | ONBOARDING_OFFBOARDING.md leaver checklist; surviving confidentiality clauses |
| A.6.6 | Confidentiality or non-disclosure agreements | Applicable | Implemented | CONFIDENTIALITY.md |
| A.6.7 | Remote working | Applicable | Implemented | distributed team; DEVICE_POLICY.md baseline (encryption, 2FA, screen lock) |
| A.6.8 | Information security event reporting | Applicable | Implemented | IR plan §3 (Slack declaration), SECURITY.md reporting channel, SECURITY_TRAINING.md topic |
| A.7.1 | Physical security perimeters | Not applicable | — | no Somnio-operated facilities process this data; cloud provider responsibility (CLOUD_SERVICES.md §2) |
| A.7.2 | Physical entry | Not applicable | — | cloud provider responsibility |
| A.7.3 | Securing offices, rooms and facilities | Not applicable | — | cloud provider responsibility; remote team |
| A.7.4 | Physical security monitoring | Not applicable | — | cloud provider responsibility |
| A.7.5 | Protecting against physical and environmental threats | Not applicable | — | cloud provider responsibility |
| A.7.6 | Working in secure areas | Not applicable | — | cloud provider responsibility |
| A.7.7 | Clear desk and clear screen | Applicable | Implemented | screen lock ≤ 5 min in DEVICE_POLICY.md |
| A.7.8 | Equipment siting and protection | Not applicable | — | cloud provider responsibility |
| A.7.9 | Security of assets off-premises | Applicable | Implemented | DEVICE_POLICY.md (encryption, loss reporting within 24 h) |
| A.7.10 | Storage media | Applicable | Implemented | database dumps only on encrypted disks, deleted after use (BACKUP_AND_RECOVERY.md §2, DATA_RETENTION.md §4) |
| A.7.11 | Supporting utilities | Not applicable | — | cloud provider responsibility |
| A.7.12 | Cabling security | Not applicable | — | cloud provider responsibility |
| A.7.13 | Equipment maintenance | Not applicable | — | cloud provider responsibility; workstations per DEVICE_POLICY.md |
| A.7.14 | Secure disposal or re-use of equipment | Applicable | Implemented | DATA_RETENTION.md §4 secure disposal; device wipe on loss/leaving |
| A.8.1 | User endpoint devices | Applicable | Implemented | DEVICE_POLICY.md |
| A.8.2 | Privileged access rights | Applicable | Implemented | admin scope + MFA (amr) in production; audited (ACCESS_CONTROL.md; services/feature_flag_service.py) |
| A.8.3 | Information access restriction | Applicable | Implemented | PrincipalDep on every route; own-subject queries; scope matrix |
| A.8.4 | Access to source code | Applicable | Implemented | open-source read; write via GitHub roles + 2FA (`lautarob` admin, `mcampbell-somnio` write — verified 2026-09-19); branch protection **active** on `main` and `develop` (CHANGE_MANAGEMENT.md §4) |
| A.8.5 | Secure authentication | Applicable | Implemented | auth/providers/*, rate limiting, error masking; MFA delegated to IdP and enforced for admin |
| A.8.6 | Capacity management | Applicable | Implemented | rate limit, body limit, Cloud Run autoscaling commitments (CLOUD_SERVICES.md §3) |
| A.8.7 | Protection against malware | Applicable | Implemented | Trivy image scan, gitleaks, pip-audit; OS protection in DEVICE_POLICY.md |
| A.8.8 | Management of technical vulnerabilities | Applicable | Implemented | PATCH_POLICY.md SLAs; scanners; scheduled scan |
| A.8.9 | Configuration management | Applicable | Implemented | pydantic-settings frozen, env.example, Dockerfile, compose, uv.lock; .env denied to tooling |
| A.8.10 | Information deletion | Applicable | Implemented | DATA_RETENTION.md; AuditRepository.purge_older_than + make purge-audit; erasure procedure |
| A.8.11 | Data masking | Applicable | Implemented | core/logging.py redact_sensitive; token fingerprint; Sentry PII off |
| A.8.12 | Data leakage prevention | Applicable | Implemented | gitleaks pre-commit/CI/weekly; .gitleaks.toml; permission denies on secrets |
| A.8.13 | Information backup | Applicable | Implemented | BACKUP_AND_RECOVERY.md; RESTORE_DRILL_LOG.md drill #1 pass; Cloud SQL backups planned |
| A.8.14 | Redundancy of information processing facilities | Applicable | Partially implemented | stateless service + health checks today; Cloud Run min-instances + Cloud SQL REGIONAL HA in `infra/run.tf`, `database.tf` — IaC committed in `infra/` (Terraform, validated in CI) — **not applied yet**, first apply with GGU-29 |
| A.8.15 | Logging | Applicable | Implemented | structlog JSON with request_id; audit_events; retention in CLOUD_SERVICES.md §4 |
| A.8.16 | Monitoring activities | Applicable | Implemented | /healthz, /readyz, Sentry, alert routing in CLOUD_SERVICES.md §5 |
| A.8.17 | Clock synchronisation | Applicable | Implemented (delegated) | container/Cloud Run host NTP; app uses injected Clock; JWT leeway ≤ 300 s |
| A.8.18 | Use of privileged utility programs | Applicable | Implemented | no shell in production image beyond runtime; non-root uid 10001; read-only FS; Alembic the only schema path |
| A.8.19 | Installation of software on operational systems | Applicable | Implemented | immutable images built in CI from the lockfile; no runtime installs |
| A.8.20 | Networks security | Applicable | Partially implemented | app-layer TrustedHost/CORS/rate limit today; private VPC, Cloud SQL private IP, VPC connector, deny-all firewall and Cloud Armor in `infra/network.tf`, `edge.tf` — IaC committed in `infra/` (Terraform, validated in CI) — **not applied yet**, first apply with GGU-29 |
| A.8.21 | Security of network services | Applicable | Implemented | TLS at ingress, HSTS in production, HTTPS-only egress. **In `dev` TLS is terminated on Cloud Run's own certificate — no load balancer, so no TLS policy of our choosing** (specs/infra/0001-dev-environment.md §5) |
| A.8.22 | Segregation of networks | Applicable | Partially implemented | one GCP project per environment, Cloud SQL private IP (`infra/`) — IaC committed in `infra/` (Terraform, validated in CI) — **not applied yet**, first apply with GGU-29 |
| A.8.23 | Web filtering | Applicable | Partially implemented | egress allow-list documented (CLOUD_SERVICES.md §6); CORS/TrustedHost allow-lists; Cloud Armor OWASP WAF + per-IP throttling in `infra/edge.tf` — **staging/production only, deliberately absent in `dev`** (risk R-16, accepted while dev holds synthetic data only) |
| A.8.24 | Use of cryptography | Applicable | Implemented | RS256/ES256/HS256 via PyJWT[crypto], TLS, encryption at rest decision (DATA_RESIDENCY_AND_TENANCY.md §3) |
| A.8.25 | Secure development life cycle | Applicable | Implemented | CHANGE_MANAGEMENT.md; SDD rules; ship gate |
| A.8.26 | Application security requirements | Applicable | Implemented | spec template §5; backend/docs/SECURITY.md |
| A.8.27 | Secure system architecture and engineering principles | Applicable | Implemented | backend/docs/ARCHITECTURE.md; .claude/rules/backend/architecture.md; layering enforced by review |
| A.8.28 | Secure coding | Applicable | Implemented | ruff S/B rules, basedpyright strict, pydantic at boundaries, parameterised SQL, Semgrep |
| A.8.29 | Security testing in development and acceptance | Applicable | Partially implemented | 100 % branch coverage, SAST, image scan; DAST and external pentest planned (VULNERABILITY_MANAGEMENT.md §2) |
| A.8.30 | Outsourced development | Not applicable | — | no outsourced development (VENDOR_MANAGEMENT.md §5) |
| A.8.31 | Separation of development, test and production environments | Applicable | Partially implemented | local/test/dev/production separated by settings and by `var.environment`, which derives a distinct control set per environment (`infra/main.tf`); dev + staging + production tfvars in `infra/environments/`; `develop` releases dev, `main` releases production behind a required reviewer. IaC committed and validated in CI — **not applied yet**, first apply with GGU-29 (CHANGE_MANAGEMENT.md §2). Whether dev gets its own GCP project is open (spec 0001 OD-1); until production is applied nothing shares a project |
| A.8.32 | Change management | Applicable | Implemented | CHANGE_MANAGEMENT.md; CODEOWNERS; PR template; EMERGENCY_CHANGE.md; CHANGELOG.md |
| A.8.33 | Test information | Applicable | Implemented | synthetic data only; uuid-generated fixtures; testcontainers databases are ephemeral |
| A.8.34 | Protection of information systems during audit testing | Applicable | Implemented | audits run read-only against the repository and local stacks (INTERNAL_AUDIT_PROGRAM.md); pentest scoped to staging |

## Planned and partial items — tracking

| Ref | Missing piece | Owner | Target |
|---|---|---|---|
| A.5.20 | signed DPAs (Google Cloud, Sentry) | Eng. management | 2026-10-31 |
| A.5.30, A.8.14, A.8.20, A.8.22, A.8.31 | **apply** the committed `infra/` Terraform. Dev first (private IP, Secret Manager, keyless delivery — but no HA, PITR or Cloud Armor); the production control set (Cloud SQL HA + PITR, Cloud Armor, its own project) lands when production is applied | TL backend | GGU-29 deploy epic |
| A.5.35 | independent readiness review; external pentest | Eng. management | 2026-Q4 / before non-demo exposure |
| A.8.29 | DAST on staging; external pentest | TL backend / Eng. management | with GGU-29 / before exposure |

These items are also risk-treatment actions in the risk register and agenda
items for the [management review](MANAGEMENT_REVIEW.md).
