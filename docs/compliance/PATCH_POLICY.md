# Patch and Vulnerability Remediation Policy

| | |
|---|---|
| **Owner** | TL backend · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC7.1, CC8.1 · ISO/IEC 27001 A.8.8 |

## SLAs (clock starts when the finding is published to us — Dependabot PR, scan issue, advisory, report)

| Severity | Definition (CVSS v3.1 or scanner severity) | Fix or documented mitigation in `main` | Deployed to production |
|---|---|---|---|
| **Critical** | 9.0–10.0, or any exploited-in-the-wild finding, or any secret leak | **48 h** | same day as merge |
| **High** | 7.0–8.9 | **7 days** | next deploy, ≤ 7 days |
| **Medium** | 4.0–6.9 | **30 days** | next release |
| **Low** | 0.1–3.9 | **90 days** or next planned dependency bump | next release |

If no fixed version exists: mitigate (disable the affected route with a flag,
WAF rule, configuration), record an [exception](EXCEPTION_POLICY.md) with an
expiry, and re-check weekly (the scheduled scan is the reminder).

## Sources we watch

- Dependabot (uv, GitHub Actions, Docker) — weekly PRs, grouped.
- `make audit` (pip-audit) in every gate run; Trivy on every image build; gitleaks on every commit/PR.
- Weekly `scheduled-scan.yaml` on `main` (pip-audit, Trivy, gitleaks) — opens a `security` issue on failure.
- Semgrep SAST on every PR.
- GitHub Security Advisories for our own repository; `security@somniosoftware.com` reports ([`SECURITY.md`](../../SECURITY.md)).
- Base image: `python:3.12-slim` refreshed by Dependabot; `apt-get upgrade` in the runtime stage so image rebuilds pick up OS fixes.

## Process

1. Finding → GitHub issue labelled `security` + severity label (Dependabot PRs count as the issue).
2. TL backend triages within 1 business day: confirm severity, decide fix/mitigate/not-affected (with justification), assign.
3. Fix PR through the normal gate (or [EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md) for Critical during an incident).
4. Close the issue with the PR link; the monthly metric "findings past SLA" is reported in the management review (target: 0).

## Runtime and platform patching

Container images are rebuilt on every merge and at least weekly (scheduled
scan builds the image); Cloud Run/Cloud SQL runtime patching is Google's
responsibility ([CLOUD_SERVICES.md](CLOUD_SERVICES.md)); developer
workstations follow [DEVICE_POLICY.md](DEVICE_POLICY.md).
