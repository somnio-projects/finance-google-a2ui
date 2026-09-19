# Security Awareness and Training

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC1.4, CC2.2 · ISO/IEC 27001 A.6.3, Cl. 7.2, 7.3 |

## Who and when

Every contributor with write access to the repository or access to a running
environment completes the **onboarding primer** before their first PR and the
**annual refresher** each September. Completion is recorded in
[isms/COMPETENCE_RECORDS.md](isms/COMPETENCE_RECORDS.md). Somnio's company-wide
security awareness training (HR-run) remains mandatory and is referenced, not
duplicated, here.

## Onboarding primer (≈ 60 minutes, self-paced)

Read, in order, then confirm by adding your row to the competence records in
your first PR:

1. `CLAUDE.md` and `backend/CLAUDE.md` — how work flows, the gate, "do not touch".
2. `backend/docs/SECURITY.md` — every control and where it is tested.
3. `.claude/rules/backend/security.md` — the rules you will be held to in review.
4. This folder's [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md), [ACCESS_CONTROL.md](ACCESS_CONTROL.md), [INCIDENT_RESPONSE_PLAN.md](INCIDENT_RESPONSE_PLAN.md) §1–3, [AI_GOVERNANCE.md](AI_GOVERNANCE.md), [CONFIDENTIALITY.md](CONFIDENTIALITY.md), [DEVICE_POLICY.md](DEVICE_POLICY.md).

## Mandatory topics (what the primer must leave you able to do)

| Topic | You can… |
|---|---|
| Credential handling | keep secrets in `.env`/Secret Manager only; recognise that `SecretStr` and `token_fingerprint` exist so raw values never reach logs, tests or Slack; rotate on suspicion |
| Secure coding in this codebase | raise `AppError` subclasses, never `HTTPException` in services; parameterised SQL only; validate at the boundary with pydantic; keep controllers logic-free |
| PII and data classes | name the four classes and the handling rules; know that emails are PII and never logged |
| Authentication & authorization | explain `PrincipalDep`, scopes, why admin needs `admin` (+ MFA in production), why a disabled flag answers 404 |
| Incident reporting | post `INCIDENT SEV-n` in `#finance-google-a2ui-dev`, preserve evidence, never wipe a container first |
| Phishing & account security | GitHub/GCP/Slack with 2FA, hardware key preferred; report suspicious messages to the security owner |
| AI-assisted development | what may and may not be pasted into the agent (no secrets, no real user data), how the human gates work |
| Change management | CODEOWNERS review, red gate = not done, emergency-change path |

## Refresher (annual, ≈ 30 minutes)

Re-read the changed documents (git log of `docs/compliance/` since your last
attestation), the year's postmortems, and re-attest in the competence records.

## Effectiveness

Measured by: zero secret-leak findings on `main` (gitleaks), zero PR reverts
for security reasons, tabletop exercise outcome. Reviewed in the management
review.
