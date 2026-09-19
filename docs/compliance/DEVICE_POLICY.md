# Workstation / Device Policy for contributors

| | |
|---|---|
| **Owner** | Security owner (TL backend), baseline inherited from Somnio IT · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC1.4, CC6.6, CC6.8 · ISO/IEC 27001 A.8.1, A.8.7 |

Somnio IT's company baseline applies to every device used for this project;
this page states the minimum the project requires and checks at onboarding.

## Minimum baseline (self-attested at onboarding, re-attested annually)

| Control | Requirement |
|---|---|
| Disk encryption | on (FileVault / BitLocker / LUKS) |
| OS and browser | supported version, automatic security updates enabled |
| Screen lock | ≤ 5 minutes, password/biometric required |
| Accounts | GitHub, Google Cloud and Slack with **2FA** (hardware key or authenticator; SMS not accepted) |
| Malware protection | OS built-in protection enabled (XProtect/Defender); no disabled Gatekeeper/SmartScreen |
| Secrets on disk | only inside the repo's git-ignored `.env` files or the OS keychain; never in notes, shell history files committed to dotfile repos, or cloud-synced folders |
| Local databases | `docker compose` volumes only; production dumps handled per [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) §2 and deleted after use |
| Remote wipe / loss | report a lost or stolen device to Somnio IT and the security owner within 24 h; rotate any credential that was on it |
| Personal devices | allowed only if they meet this baseline; production access (GCP) from managed devices only once IaC/production exists |

## Development tooling

- Docker Desktop kept current (it runs the local Postgres and the sandboxed agent commands).
- Claude Code runs with the repository's `.claude/settings.json` permissions, which deny reading `.env*` and key files; do not override them locally (`settings.local.json` is git-ignored but reviewed on request).
- Pre-commit hooks installed (`pre-commit install`) so gitleaks runs before every commit.

## Records

Attestation rows live in [isms/COMPETENCE_RECORDS.md](isms/COMPETENCE_RECORDS.md)
("device baseline: yes, date").
