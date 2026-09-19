# Risk Assessment — methodology, register and treatment plan

| | |
|---|---|
| **Owner** | Security owner (TL backend) |
| **Approved by** | Engineering management |
| **Version** | 1.0 — 2026-09-19 (first annual assessment) |
| **Next review** | 2027-09-19, or after any incident ≥ SEV-2, new data class, new vendor or new deployment target |
| **Maps to** | SOC 2 CC3.1, CC3.2, CC3.4 · ISO/IEC 27001 Cl. 6.1.2, 6.1.3, 8.2, 8.3 |

## 1. Methodology (Cl. 6.1.2)

- **Asset-based.** Each asset in §2 is assessed against the threats in §3.
- **Likelihood** 1–5 (1 = rare, ≥ 5 years · 3 = possible, yearly · 5 = expected, monthly).
- **Impact** 1–5 on the worst of C/I/A (1 = negligible · 3 = service degraded or internal data exposed · 5 = user data breach, regulatory notification, or total loss).
- **Risk score** = likelihood × impact. **Acceptance criteria:** ≤ 6 accept · 7–12 treat within the year · ≥ 13 treat before the next release.
- **Treatment options:** modify (add control), retain (accept, owner signs), avoid, share (insurance/contract).
- Residual risk is re-scored after treatment. The register is re-run at each annual review and after every incident postmortem.

## 2. Asset inventory

| ID | Asset | Class ([DATA_CLASSIFICATION](DATA_CLASSIFICATION.md)) | Owner |
|---|---|---|---|
| AS-1 | `audit_events` table (subject, provider, action, token fingerprint, request id) | Confidential | Security owner |
| AS-2 | `feature_flags` table | Internal | Security owner |
| AS-3 | Auth material: `AUTH_JWT_SECRET`, OIDC issuer config | Restricted | Security owner |
| AS-4 | Third-party model key (Gemini, future spec) | Restricted | Security owner |
| AS-5 | Sentry DSN and telemetry | Internal | Security owner |
| AS-6 | Source code, harness, CI configuration | Public (open source) / integrity critical | TL backend |
| AS-7 | CI secrets (`GITHUB_TOKEN`, future deploy credentials) | Restricted | Eng. management |
| AS-8 | Production runtime (Cloud Run + Cloud SQL, planned — ADR-F) | — | TL backend |
| AS-9 | Contributor workstations and accounts (GitHub, GCP, Slack) | — | Each contributor |

## 3. Risk register

| ID | Asset | Threat / vulnerability | L | I | Score | Treatment | Controls (evidence) | Residual |
|---|---|---|---|---|---|---|---|---|
| R-1 | AS-3 | Forged or replayed bearer token | 2 | 5 | 10 | Modify | Signature/iss/aud/exp/iat verification, `sub` required, OIDC via JWKS, leeway ≤ 300 s (`auth/providers/*`, tests) | 1×5 = 5 |
| R-2 | AS-1 | Cross-user read of audit history | 2 | 4 | 8 | Modify | Queries keyed by `principal.subject` (`AuditRepository.list_for_subject`), integration test | 1×4 = 4 |
| R-3 | AS-3/4/7 | Secret committed to git or baked into image | 3 | 5 | 15 | Modify | gitleaks pre-commit + CI + weekly, `.env` denied to tooling, `SecretStr`, `.dockerignore`, Trivy | 1×5 = 5 |
| R-4 | AS-1/2 | Credential-stuffing / brute force / DoS on the API | 3 | 3 | 9 | Modify | Rate limit per IP + token fingerprint, body limit, TrustedHost, CORS allow-list; Cloud Armor planned (CLOUD_SERVICES) | 2×3 = 6 |
| R-5 | AS-6 | Vulnerable dependency or base image | 4 | 4 | 16 | Modify | pip-audit in gate, Trivy CRITICAL/HIGH blocking, Dependabot weekly, scheduled scan, PATCH_POLICY SLAs | 2×3 = 6 |
| R-6 | AS-1 | Data loss (bad migration, accidental drop, volume loss) | 2 | 5 | 10 | Modify | Alembic-only schema path, immutable merged revisions, backups + quarterly restore drill (BACKUP_AND_RECOVERY, RESTORE_DRILL_LOG); Cloud SQL automated backups planned | 1×4 = 4 |
| R-7 | AS-1/5 | PII or token leaked through logs/telemetry | 3 | 4 | 12 | Modify | `redact_sensitive`, fingerprint instead of token, Sentry `send_default_pii=False`, body never sent, error masking | 1×4 = 4 |
| R-8 | AS-2 | Unauthorised feature-flag toggle (privilege escalation) | 2 | 3 | 6 | Modify | `admin` scope enforced in service, audit event per toggle, MFA (`amr`) requirement for admin in production (ACCESS_CONTROL) | 1×3 = 3 |
| R-9 | AS-6 | Malicious or careless change merged without review | 2 | 4 | 8 | Modify | CODEOWNERS, ship gate == CI, `backend-reviewer`, harness log; branch-protection ruleset on `main` exported but **not enforced yet** (enable before PR #2 merges — treatment plan) | 2×4 = 8 until enforced, then 1×4 = 4 |
| R-10 | AS-6 | AI-generated code introduces a defect or insecure pattern | 3 | 3 | 9 | Modify | Spec approval, 100 % branch coverage, ruff `S`, Semgrep, human PR review; AI_GOVERNANCE | 2×2 = 4 |
| R-11 | AS-8 | Regional outage / single instance unavailable | 3 | 3 | 9 | Retain (demo) → Modify (prod) | Health probes, stateless service, RPO/RTO in BCP; Cloud Run multi-instance + Cloud SQL HA before non-demo exposure | 2×3 = 6 |
| R-12 | AS-9 | Contributor account or workstation compromise | 2 | 4 | 8 | Modify / Share | GitHub 2FA required by org, DEVICE_POLICY baseline, onboarding/offboarding checklist, least-privilege repo roles | 1×4 = 4 |
| R-13 | AS-4/5 | Vendor (Sentry, Google) changes data handling or suffers a breach | 2 | 3 | 6 | Share | VENDOR_MANAGEMENT register, DPAs, annual review, PII never sent to Sentry | 1×3 = 3 |
| R-14 | AS-1 | Retention violation (data kept forever, erasure impossible) | 3 | 3 | 9 | Modify | DATA_RETENTION policy, `audit_events` purge (repository method + scheduled job), erasure procedure | 1×3 = 3 |
| R-15 | AS-8 | Unencrypted data at rest in production | 2 | 4 | 8 | Modify | Cloud SQL encryption at rest (Google-managed keys, CMEK optional) declared in DATA_RESIDENCY_AND_TENANCY; local compose is dev only | 1×4 = 4 |

All residual scores are ≤ 6 (accepted). R-11 is explicitly **retained** while
the service is a demo behind Google reviewer credentials; the acceptance
expires when the service is exposed beyond the demo (owner: TL backend).

## 4. Risk treatment plan (Cl. 6.1.3)

| Action | Closes | Owner | Due | Status |
|---|---|---|---|---|
| Publish this policy set and the SoA | R-9, R-10, governance gaps | Security owner | 2026-09-19 | done |
| Enable the `main` ruleset: 1 code-owner approval, required checks (`gate`, `gitleaks`, `semgrep`, `docker build`), no force-push/deletion, admins included | R-9 | TL backend (repo admin) | before PR #2 merges | pending — ruleset exists disabled (`evidence/branch-protection-ruleset.json`) |
| `audit_events` retention purge + scheduled job | R-14 | TL backend | 2026-09-19 (method), job at deploy (GGU-29) | in progress |
| MFA (`amr`) requirement on admin routes, on by default in production | R-8 | TL backend | 2026-09-19 | done |
| Weekly scheduled scan + Semgrep SAST in CI | R-5, R-10 | TL backend | 2026-09-19 | done |
| First restore drill and quarterly schedule | R-6 | Security owner | 2026-09-19 | done (see RESTORE_DRILL_LOG) |
| Cloud Run + Cloud SQL IaC with automated backups, HA, private IP, Cloud Armor | R-4, R-6, R-11, R-15 | TL backend | with GGU-29 (deploy epic) | planned |
| External penetration test | R-1, R-2, R-4 | Eng. management | before non-demo exposure | planned |
| Execute/file DPAs with Sentry and Google Cloud | R-13 | Eng. management | 2026-10-31 | planned |

## 5. Approval

Approved by engineering management through the merge of this document.
Residual-risk acceptance for R-11 signed by the TL backend in the same merge.
