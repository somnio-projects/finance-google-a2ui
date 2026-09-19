# Competence and Awareness Records

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 |
| **Maps to** | ISO/IEC 27001 Cl. 7.2, 7.3, A.6.3 · SOC 2 CC1.4 |

Each contributor adds their own row in a PR (the PR is the attestation). The
security primer and refresher are defined in
[../SECURITY_TRAINING.md](../SECURITY_TRAINING.md); the device baseline in
[../DEVICE_POLICY.md](../DEVICE_POLICY.md). Somnio's company-wide training
records are held by HR and referenced, not copied.

## Attestations

| Contributor | Role | Security primer (date) | Device baseline (date) | Confidentiality agreement on file (HR) | Annual refresher due | Notes |
|---|---|---|---|---|---|---|
| Lautaro Bertuzzi (`@lautarob`) | TL backend, security owner | 2026-09-19 (author of the primer) | 2026-09-19 | yes | 2027-09 | Somnio codelab 2 (Claude Code harness) completed 2026-09 |
| Mario Campbell R (`@mcampbell-somnio`) | backend engineer, reviewer | pending — first PR (management review D-7) | pending | yes | — | joined 2026-09-18 |
| Patricio Burzaco (`@pburzaco-somnio`) | PM / integrator (triage access) | pending | pending | yes | — | no write access to backend paths |
| Timur Tkharkakhov (`@tinted-knight`) | Flutter / Epic 0 | pending (frontend track) | pending | yes | — | |

## Role competence requirements

| Role | Required competence | Evidence |
|---|---|---|
| Security owner | secure design of web APIs, OIDC/JWT, SOC 2 / ISO 27001 controls, incident command | this policy set; audits ≥ 90; drill execution |
| Backend engineer | the harness rules, FastAPI/SQLAlchemy secure coding, testing to 100 % branch coverage | green gates on own PRs; reviewer sign-offs |
| Reviewer (code owner) | able to run and interpret the gate and the `backend-reviewer` output; knows the security rules | review history |
| Incident commander / backup | IR plan and DR plan; access to the systems in DR §3 | tabletop participation (first: 2026-Q4) |

Gaps identified at the annual review become training actions here.
