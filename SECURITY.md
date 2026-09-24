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
- Automated scanning, by what each one actually covers:
  - **Every pull request, whatever it touches** — gitleaks over the full history, shellcheck over every tracked script (`.github/workflows/repo-ci.yaml`, no `paths:` filter).
  - **Pull requests touching `backend/**`** — Semgrep, pip-audit and a Trivy image scan (`.github/workflows/backend-ci.yaml`).
  - **Pull requests touching `infra/**`** — `trivy config` over the Terraform (`.github/workflows/infra-ci.yaml`).
  - **Weekly on `main`** — pip-audit, SBOM, Trivy, gitleaks (`.github/workflows/scheduled-scan.yaml`); Dependabot weekly for uv, GitHub Actions, Docker and the `frontend/` pub workspace.
  - **Not covered today:** no SAST over Dart and no CVE scan of the Flutter dependency graph beyond Dependabot's updates (`docs/compliance/VULNERABILITY_MANAGEMENT.md` §1 carries the rows and their owners). A third gap — no image build or CVE scan for `client_flutter/` — closed on 2026-09-22 by that app being retired rather than by a gate being written, which is worth saying plainly: the risk is gone because the artefact is.

  This list replaces a single line that read "gitleaks, pip-audit, Trivy and Semgrep on every PR (`backend-ci.yaml`)". That workflow is `paths:`-scoped to `backend/**`, so the claim was false for every frontend-only or client-only pull request — which by 2026-09-20 was most of them. Secret scanning now genuinely does run on every pull request; the rest is listed by its real scope rather than rounded up.
