# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

- Email `security@somniosoftware.com` (or `lbertuzzi@somniosoftware.com`, TL backend) with a description, reproduction steps and impact.
- You will get an acknowledgement within **2 business days** and a triage decision (severity, owner, target fix date) within **5 business days**.
- We follow coordinated disclosure: we ask for 90 days before public disclosure, or until a fix ships, whichever is first. We credit reporters who wish to be credited.

## Fix targets (see `docs/compliance/PATCH_POLICY.md`)

| Severity (CVSS v3.1) | Fix / mitigation target |
|---|---|
| Critical (9.0–10.0) | 48 hours |
| High (7.0–8.9) | 7 days |
| Medium (4.0–6.9) | 30 days |
| Low (0.1–3.9) | next planned release |

## Supported versions

Only `main` and the latest tagged release receive security fixes. The project is a reference showcase; there are no long-term-support branches.

## Where the controls live

- Control matrix (SOC 2 TSC ↔ ISO/IEC 27001 Annex A): [`backend/docs/SECURITY.md`](backend/docs/SECURITY.md)
- Compliance corpus (policies, ISMS artifacts, runbooks): [`docs/compliance/README.md`](docs/compliance/README.md)
- Incident response and breach notification: [`docs/compliance/INCIDENT_RESPONSE_PLAN.md`](docs/compliance/INCIDENT_RESPONSE_PLAN.md), [`docs/compliance/BREACH_NOTIFICATION_SLA.md`](docs/compliance/BREACH_NOTIFICATION_SLA.md)
- Automated scanning: gitleaks, pip-audit, Trivy and Semgrep on every PR (`.github/workflows/backend-ci.yaml`) and weekly on `main` (`.github/workflows/scheduled-scan.yaml`); Dependabot weekly.
