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

- The Flutter client's runtime data (it stores nothing; it is in scope only for secure development practices once frontend work starts — GGU-1).
- Physical security of facilities (Google's responsibility; the team is remote).
- Somnio corporate IT systems beyond the accounts listed above (covered by Somnio's company ISMS).
- Google's own systems and the Gemini model internals.

## Interfaces and dependencies

Identity provider (OIDC/Firebase) → API; API → PostgreSQL; API → Sentry;
API → Gemini (future); GitHub → CI → container registry → Cloud Run (future).
Each interface's security is described in `backend/docs/SECURITY.md` and
`docs/compliance/CLOUD_SERVICES.md`.
