# Contributors and development disclosure

## Who builds this

finance-google-a2ui is an open-source reference application built by **Somnio Software** as a showcase with **Google** for the A2UI protocol (Jira project `GGU`). It is not a paid client engagement; there is no client data in the system.

| Role | Person | Handle |
|---|---|---|
| Tech lead backend, security owner | Lautaro Bertuzzi | `@lautarob` |
| Backend engineer, reviewer | Mario Campbell R | `@mcampbell-somnio` |
| Project manager, integrator | Patricio Burzaco | `@pburzaco-somnio` |
| Epic 0 / Flutter catalog | Timur Tkharkakhov | `@tinted-knight` |
| Engineering management | Guillermo Hilal | `@ghilal-somnio` |
| UX/UI | Miriam Petersen | — |

All contributors are Somnio Software employees or contractors bound by Somnio's employment/contractor agreements, which include confidentiality obligations (`docs/compliance/CONFIDENTIALITY.md`). No development is outsourced outside Somnio.

## AI-assisted development

Code, tests and documentation in this repository are produced with **Claude Code** (Anthropic) operating inside the harness described in `docs/DEV_HARNESS.md`. Every AI-generated change goes through the same human gates as any other change: an approved spec (`specs/`), the automated ship gate (`make gate` == CI), the read-only `backend-reviewer` agent, and a human pull-request review by a code owner (`.github/CODEOWNERS`). The governance of that usage — scope, data handling, human review and audit trail — is documented in `docs/compliance/AI_GOVERNANCE.md` and `docs/compliance/AI_DATA_HANDLING.md`.

Commits and pull requests carry no AI attribution lines by team decision (`CLAUDE.md`); the harness log (`.claude/harness-log.md`) is the record of what the agent did in each iteration.

## How to contribute

Read `CLAUDE.md`, then `docs/DEV_HARNESS.md`. Open a spec before code, keep the gate green, and follow `CODE_OF_CONDUCT.md`.
