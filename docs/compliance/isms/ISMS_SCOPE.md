# ISMS Scope Statement

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Approved by** engineering management · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | ISO/IEC 27001 Cl. 4.1, 4.2, 4.3 |

## Organisation and context (Cl. 4.1)

Somnio Software (software consultancy, Uruguay/Argentina) develops and
operates **finance-google-a2ui**, an open-source reference application built
with Google to showcase the A2UI protocol: an AI agent answers portfolio
questions by composing UI components. The application is a demo — it holds no
paying-client data — but it is designed and operated to production security
standards because that is what the showcase demonstrates.

## Interested parties and requirements (Cl. 4.2)

| Party | Expectation |
|---|---|
| Google (program sponsor, reviewers) | a credible, secure reference implementation; reviewer credentials handled safely; no embarrassment from a security incident |
| Somnio management | a reusable, auditable foundation; SOC 2 / ISO 27001 readiness ≥ 90 on the Somnio CLI audits |
| Contributors | clear rules, tooling that enforces them, no personal exposure |
| Open-source users | honest documentation of what is and is not implemented; a way to report vulnerabilities |
| Regulators (potential, if personal data of protected residents is ever processed) | GDPR-style handling: minimisation, retention, breach notification |

## Scope (Cl. 4.3)

**In scope**

- The backend service in `backend/` (FastAPI, Python 3.12): source, tests, container image, Alembic migrations.
- Its data: PostgreSQL databases in every environment (local compose, CI testcontainers, planned Cloud SQL) — `audit_events`, `feature_flags`.
- Delivery pipeline: GitHub repository `somnio-projects/finance-google-a2ui`, GitHub Actions workflows, Dependabot, pre-commit, the Somnio CLI audits.
- The Claude Code harness (`.claude/`, `CLAUDE.md`, `specs/`, `docs/`) as the change-management and AI-governance mechanism.
- People: Somnio staff and contractors listed in `CONTRIBUTORS.md`, their accounts (GitHub, Google Cloud, Slack, Jira) and workstations as far as `DEVICE_POLICY.md` reaches.
- Third-party services in `docs/compliance/CLOUD_SERVICES.md` and `VENDOR_MANAGEMENT.md`, under the shared-responsibility model.
- Planned production runtime on Google Cloud (`us-central1`) — controls are specified now and become operational with the deploy epic (GGU-29).

**Out of scope**

- The Flutter clients' runtime data. Both apps store nothing: neither declares a storage package, and `frontend/`'s ETag cache is in memory for the process lifetime. The **code** of both is in scope for secure development practices **now, not conditionally** — `frontend/` merged 2026-09-20 with its own gate and `client_flutter/` has shipped for longer, so the previous wording ("once frontend work starts — GGU-1") described a state this project left. What is in scope and not yet covered is recorded as gaps in `VULNERABILITY_MANAGEMENT.md` §1 (no Dart SAST, no Dart CVE scanning, no image scan for `client_flutter/`), not waived here.
- Physical security of facilities (Google's responsibility; the team is remote).
- Somnio corporate IT systems beyond the accounts listed above (covered by Somnio's company ISMS).
- Google's own systems and the Gemini model internals.

## Interfaces and dependencies

Identity provider (OIDC/Firebase) → API; API → PostgreSQL; API → Sentry;
API → Gemini (future); GitHub → CI → container registry → Cloud Run (future).
Each interface's security is described in `backend/docs/SECURITY.md` and
`docs/compliance/CLOUD_SERVICES.md`.
