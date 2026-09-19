# Onboarding / Offboarding checklist

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC6.2, CC6.3 · ISO/IEC 27001 A.5.16, A.5.18, A.6.5 |

Copy the relevant list into a GitHub issue titled `access: <name> (join|leave)`
labelled `access`; the closed issue is the record sampled in the quarterly
access review ([ACCESS_CONTROL.md](ACCESS_CONTROL.md) §6).

## Joiner

- [ ] Somnio employment/contractor agreement with confidentiality clause on file (HR confirms) — [CONFIDENTIALITY.md](CONFIDENTIALITY.md)
- [ ] Device baseline attested — [DEVICE_POLICY.md](DEVICE_POLICY.md)
- [ ] GitHub: added to `somnio-projects/finance-google-a2ui` with the **least role needed** (`write` for engineers, `triage` for PM/UX); 2FA verified by org policy
- [ ] Slack: `#finance-google-a2ui-dev`
- [ ] Jira: `GGU` project role
- [ ] Google Cloud (only when production exists): project IAM role per `CLOUD_SERVICES.md` §3, never `owner`
- [ ] Security primer completed and row added to [isms/COMPETENCE_RECORDS.md](isms/COMPETENCE_RECORDS.md) — [SECURITY_TRAINING.md](SECURITY_TRAINING.md)
- [ ] Local setup from `CLAUDE.md`: `cp backend/env.example backend/.env` (own values), `pre-commit install`, `make gate` green once

## Mover (role change)

- [ ] Re-evaluate GitHub/GCP roles; remove what the new role does not need
- [ ] Update `.github/CODEOWNERS` if review responsibilities change

## Leaver (same business day as the notice)

- [ ] GitHub collaborator removed; open PRs reassigned; personal access tokens/deploy keys they created revoked
- [ ] Slack channel, Jira, Google Cloud IAM removed
- [ ] Any shared secret they had access to **rotated** (`AUTH_JWT_SECRET`, Sentry DSN, model key, CI secrets) — record in the access issue
- [ ] Local `.env` files and database dumps deleted by the leaver (self-attested in the issue)
- [ ] `CONTRIBUTORS.md` and `CODEOWNERS` updated
- [ ] Confidentiality obligations reminder sent (HR)

## Records

Access issues + the quarterly review table in ACCESS_CONTROL.md.
